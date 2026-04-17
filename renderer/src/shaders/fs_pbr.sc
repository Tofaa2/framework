$input v_normal, v_pos, v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_albedo, 0);
SAMPLER2D(s_metallicRoughness, 1);
SAMPLER2D(s_occlusion, 2);
SAMPLER2D(s_irradiance, 10);
SAMPLER2D(s_prefiltered, 11);
SAMPLER2D(s_brdfLut, 12);

uniform vec4 u_albedo;
uniform vec4 u_metallicRoughness;
uniform vec4 u_emissive;
uniform vec4 u_occlusionStrength;
uniform vec4 u_useTextures;

uniform vec4 u_lights[32];
uniform vec4 u_lightParams;

uniform vec4 u_envIntensity;

uniform mat4 u_lightMatrix;
SAMPLER2D(s_shadowMap, 3);

#define LIGHT_TYPE_DIRECTIONAL 0.0
#define LIGHT_TYPE_POINT 1.0
#define LIGHT_TYPE_SPOT 2.0

vec2 dirToLatLong(vec3 dir)
{
    float phi = atan2(dir.y, dir.x);
    float theta = acos(dir.z);
    return vec2(phi * 0.15915494, theta * 0.31830988);
}

float D_GGX(float NdotH, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (denom * denom);
}

vec3 F_Schlick(float cosTheta, vec3 F0)
{
    return F0 + (vec3(1.0, 1.0, 1.0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 F_SchlickRoughness(float cosTheta, vec3 F0, float roughness)
{
    vec3 roughnessVec = vec3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness);
    return F0 + (max(roughnessVec, F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float G_Schlick(float NdotV, float NdotL, float roughness)
{
    float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    float gv = NdotV / (NdotV * (1.0 - k) + k);
    float gl = NdotL / (NdotL * (1.0 - k) + k);
    return gv * gl;
}

float fresnelSchlick(float cosTheta, float F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float getAttenuation(float dist, float radius)
{
    float x = clamp(dist / radius, 0.0, 1.0);
    x = 1.0 - x;
    return x * x;
}

float getSpotFactor(vec3 L, vec3 lightDir, float spotParams)
{
    float cosAngle = dot(-L, lightDir);
    float cosInner = 1.0 - spotParams * 0.5;
    float cosOuter = cosInner - spotParams;
    return clamp((cosAngle - cosOuter) / (cosInner - cosOuter), 0.0, 1.0);
}

float calcShadow(vec4 shadowPos)
{
    vec3 projCoords = shadowPos.xyz / shadowPos.w;
    projCoords = projCoords * 0.5 + 0.5;
    
    if (projCoords.z > 1.0) return 0.0;
    if (projCoords.x < 0.0 || projCoords.x > 1.0) return 0.0;
    if (projCoords.y < 0.0 || projCoords.y > 1.0) return 0.0;
    
    float closestDepth = texture2D(s_shadowMap, projCoords.xy).r;
    float currentDepth = projCoords.z;
    float bias = 0.001;
    return currentDepth - bias > closestDepth ? 1.0 : 0.0;
}

vec3 getIrradiance(vec3 N)
{
    vec3 result = vec3(0.0, 0.0, 0.0);
    if (u_envIntensity.w > 0.5) {
        vec2 uv = dirToLatLong(N);
        result = texture2D(s_irradiance, uv).rgb * u_envIntensity.x * 0.5;
    }
    return result;
}

vec3 getPrefilteredReflection(vec3 R, float roughness)
{
    vec3 result = vec3(0.0, 0.0, 0.0);
    if (u_envIntensity.w > 0.5) {
        vec2 uv = dirToLatLong(R);
        result = texture2D(s_prefiltered, uv).rgb * u_envIntensity.x * 0.5;
    }
    return result;
}

vec2 getBRDF(vec3 N, vec3 V, float roughness)
{
    if (u_envIntensity.w > 0.5) {
        float NdotV = max(dot(N, V), 0.0);
        return texture2D(s_brdfLut, vec2(NdotV, roughness)).xy;
    }
    return vec2(0.04, 1.0);
}

void main()
{
    vec3 N = normalize(v_normal);
    vec3 camPos = mul(u_invView, vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 V = normalize(camPos - v_pos);
    vec3 R = reflect(-V, N);

    float metallic = u_metallicRoughness.x;
    float roughness = u_metallicRoughness.y;
    roughness = max(roughness, 0.04);

    vec4 albedo4 = u_albedo;
    if (u_useTextures.x > 0.5) {
        albedo4 *= texture2D(s_albedo, v_texcoord0);
    }
    if (u_useTextures.z > 0.5) {
        vec4 mr = texture2D(s_metallicRoughness, v_texcoord0);
        metallic = mr.b;
        roughness = mr.g;
    }

    float occlusion = 1.0;
    if (u_useTextures.y > 0.5) {
        occlusion = texture2D(s_occlusion, v_texcoord0).r;
    }

    vec3 albedo = albedo4.xyz;
    vec3 F0 = mix(vec3(0.04, 0.04, 0.04), albedo, metallic);

    vec3 ambient = vec3(0.0, 0.0, 0.0);
    vec3 diffuse_acc = vec3(0.0, 0.0, 0.0);
    vec3 specular_acc = vec3(0.0, 0.0, 0.0);

    if (u_envIntensity.w > 0.5) {
        vec3 irradiance = getIrradiance(N);

        vec3 F = F_SchlickRoughness(max(dot(N, V), 0.0), F0, roughness);

        vec3 kD = (vec3(1.0, 1.0, 1.0) - F) * (1.0 - metallic);
        vec3 diffuse_ibl = kD * albedo * irradiance;

        vec3 prefiltered = getPrefilteredReflection(R, roughness);
        vec2 brdf = getBRDF(N, V, roughness);
        vec3 specular_ibl = prefiltered * (F * brdf.x + brdf.y);

        ambient = (diffuse_ibl + specular_ibl) * occlusion;
    }

    int numLights = int(u_lightParams.x);
    for (int i = 0; i < 8; i++)
    {
        if (i >= numLights) break;

        int lightBase = i * 4;
        vec3 lightPos = u_lights[lightBase + 0].xyz;
        vec3 lightDir = u_lights[lightBase + 1].xyz;
        vec3 lightCol = u_lights[lightBase + 2].xyz;
        float intensity = u_lights[lightBase + 2].w;
        float lightType = u_lights[lightBase + 3].x;
        float radius = u_lights[lightBase + 3].y;
        vec2 spotParams = u_lights[lightBase + 3].yz;

        vec3 L = lightDir;
        float attenuation = 1.0;
        float NdotL = 0.0;

        if (lightType == LIGHT_TYPE_DIRECTIONAL) {
            L = normalize(-lightDir);
            NdotL = max(dot(N, L), 0.0);
        }
        else if (lightType == LIGHT_TYPE_POINT) {
            L = lightPos - v_pos;
            float dist = length(L);
            L = normalize(L);
            NdotL = max(dot(N, L), 0.0);
            attenuation = getAttenuation(dist, radius);
        }
        else if (lightType == LIGHT_TYPE_SPOT) {
            L = lightPos - v_pos;
            float dist = length(L);
            L = normalize(L);
            NdotL = max(dot(N, L), 0.0);
            float spotFactor = getSpotFactor(L, lightDir, spotParams.y);
            attenuation = getAttenuation(dist, radius) * spotFactor;
        }

        if (NdotL > 0.0) {
            vec3 H = normalize(L + V);
            float NdotH = max(dot(N, H), 0.0);
            float NdotV = max(dot(N, V), 0.0);
            float HdotV = max(dot(H, V), 0.0);

            float D = D_GGX(NdotH, roughness);
            float G = G_Schlick(NdotV, NdotL, roughness);
            vec3 F = F_Schlick(HdotV, F0);

            vec3 lightContribution = lightCol * intensity * attenuation;

            diffuse_acc += albedo * lightContribution * NdotL * (1.0 - metallic);
            specular_acc += F * lightContribution * D * G * NdotL;
        }
    }

    vec3 colour = ambient + diffuse_acc + specular_acc;
    
    vec4 shadowPos = mul(u_lightMatrix, vec4(v_pos, 1.0));
    float shadow = calcShadow(shadowPos);
    
    float shadowAmount = 1.0 - shadow * 0.5;
    colour *= shadowAmount;
    
    gl_FragColor = vec4(colour, albedo4.w);
}
