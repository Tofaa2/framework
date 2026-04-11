$input v_color0, v_texcoord0, v_normal, v_worldPos, v_tangent

#include <bgfx_shader.sh>

SAMPLER2D(s_tex, 0);

SAMPLERCUBE(s_irradiance, 1);
SAMPLERCUBE(s_prefiltered, 2);
SAMPLER2D(s_brdfLUT, 3);

uniform vec4 u_baseColor;
uniform vec4 u_metallicRoughness;
uniform vec4 u_camPos;
uniform vec4 u_lightPos0;
uniform vec4 u_lightColor0;
uniform vec4 u_iblStrength;

#define PI 3.14159265359
#define ONE vec3(1.0, 1.0, 1.0)
#define F0_BASE vec3(0.04, 0.04, 0.04)

vec3 F0(float metallic, vec3 baseColor) {
    return mix(F0_BASE, baseColor, metallic);
}

float D_GGX(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float d = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (PI * d * d);
}

float G_SchlickGGX(float NdotX, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotX / (NdotX * (1.0 - k) + k);
}

float G_Smith(float NdotV, float NdotL, float roughness) {
    return G_SchlickGGX(NdotV, roughness) * G_SchlickGGX(NdotL, roughness);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0_val) {
    return F0_val + (ONE - F0_val) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0_val, float roughness) {
    vec3 r = max(ONE * (1.0 - roughness), F0_val);
    return F0_val + (r - F0_val) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 BRDF(vec3 N, vec3 V, vec3 L, vec3 baseColor, float metallic, float roughness) {
    vec3 H = normalize(V + L);
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(V, H), 0.0);
    
    if (NdotL <= 0.0) return vec3(0.0, 0.0, 0.0);
    
    vec3 F = fresnelSchlick(VdotH, F0(metallic, baseColor));
    float D = D_GGX(NdotH, roughness);
    float G = G_Smith(NdotV, NdotL, roughness);
    
    vec3 specular = (D * G * F) / (4.0 * NdotV * NdotL + 0.0001);
    vec3 kD = (ONE - F) * (1.0 - metallic);
    vec3 diffuse = kD * baseColor / PI;
    
    return (diffuse + specular) * NdotL;
}

vec3 sampleRadiance(vec3 dir) {
    return textureCube(s_prefiltered, dir).rgb;
}

vec3 sampleIrradiance(vec3 dir) {
    return textureCube(s_irradiance, dir).rgb;
}

vec3 computeIBL(vec3 N, vec3 V, vec3 baseColor, float metallic, float roughness) {
    vec3 F = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0(metallic, baseColor), roughness);
    vec3 kD = (ONE - F) * (1.0 - metallic);
    
    vec3 irradiance = sampleIrradiance(N);
    vec3 diffuseIBL = irradiance * baseColor * kD;
    
    vec3 R = vec3(-V.x, V.y, -V.z);
    vec3 prefilteredColor = sampleRadiance(R);
    vec2 envBRDF = texture2D(s_brdfLUT, vec2(max(dot(N, V), 0.0), roughness)).rg;
    vec3 specularIBL = prefilteredColor * (F * envBRDF.x + envBRDF.y);
    
    return diffuseIBL + specularIBL;
}

void main()
{
    vec4 texColor = texture2D(s_tex, v_texcoord0);
    vec3 baseColor = texColor.rgb;
    if (length(baseColor) < 0.01) {
        baseColor = u_baseColor.rgb;
    }

    float metallic = u_metallicRoughness.x;
    float roughness = max(u_metallicRoughness.y, 0.04);

    vec3 N = normalize(v_normal);
    vec3 V = normalize(u_camPos.xyz - v_worldPos);
    vec3 L = normalize(u_lightPos0.xyz - v_worldPos);

    float distance = length(u_lightPos0.xyz - v_worldPos);
    float attenuation = 1.0 / (1.0 + 0.09 * distance + 0.032 * distance * distance);
    vec3 radiance = u_lightColor0.rgb * attenuation;

    vec3 Lo = BRDF(N, V, L, baseColor, metallic, roughness) * radiance;

    float iblStrength = u_iblStrength.x;
    vec3 ibl = computeIBL(N, V, baseColor, metallic, roughness) * iblStrength;

    vec3 ambient = baseColor * 0.15;
    vec3 color = ambient + Lo + ibl;
    
    color = color / (color + ONE);
    
    color.r = pow(color.r, 0.454);
    color.g = pow(color.g, 0.454);
    color.b = pow(color.b, 0.454);

    gl_FragColor = vec4(color, 1.0);
}
