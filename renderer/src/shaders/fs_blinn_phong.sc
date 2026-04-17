$input v_normal, v_pos, v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_texColor, 0);

uniform vec4 u_albedo;
uniform vec4 u_specular;
uniform vec4 u_useTexture;

uniform vec4 u_lights[32];
uniform vec4 u_lightParams;

#define LIGHT_TYPE_DIRECTIONAL 0.0
#define LIGHT_TYPE_POINT 1.0
#define LIGHT_TYPE_SPOT 2.0

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

void main()
{
    vec3 N = normalize(v_normal);

    vec3 camPos = mul(u_invView, vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 V      = normalize(camPos - v_pos);

    vec4 base = u_albedo;
    if (u_useTexture.x > 0.5)
    {
        base *= texture2D(s_texColor, v_texcoord0);
    }

    vec3 ambient = base.xyz * 0.08;
    vec3 diffuse_acc  = vec3(0.0, 0.0, 0.0);
    vec3 specular_acc = vec3(0.0, 0.0, 0.0);

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
            vec3 lightContribution = lightCol * intensity * attenuation;
            diffuse_acc += base.xyz * lightContribution * NdotL;

            vec3 H = normalize(L + V);
            float NdotH = max(dot(N, H), 0.0);
            specular_acc += u_specular.xyz * lightContribution * pow(NdotH, u_specular.w) * NdotL;
        }
    }

    vec3 colour = ambient + diffuse_acc + specular_acc;
    gl_FragColor = vec4(colour, base.a);
}
