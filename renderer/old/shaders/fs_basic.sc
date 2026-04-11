$input v_color0, v_texcoord0, v_normal, v_world_pos

#include <bgfx_shader.sh>

SAMPLER2D(s_texColor, 0);

// Simple directional light uniforms (set via material)
uniform vec4 u_lightDir;    // xyz = direction (world space), w = unused
uniform vec4 u_lightColor;  // rgb = color, a = ambient intensity
uniform vec4 u_baseColor;   // rgba tint (default 1,1,1,1)

void main()
{
    // Sample texture; white fallback when unbound (sampler returns white)
    vec4 tex = texture2D(s_texColor, v_texcoord0);

    // Vertex color * texture * base tint
    vec4 albedo = tex * v_color0 * u_baseColor;

    // Simple Lambert diffuse
    vec3 N = normalize(v_normal);
    vec3 L = normalize(-u_lightDir.xyz);
    float NdotL = max(dot(N, L), 0.0);

    float ambient  = u_lightColor.a;
    vec3  diffuse  = u_lightColor.rgb * NdotL;
    vec3  lighting = clamp(diffuse + vec3_splat(ambient), 0.0, 1.0);

    gl_FragColor = vec4(albedo.rgb * lighting, albedo.a);
}
