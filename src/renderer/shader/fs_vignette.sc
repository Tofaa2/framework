$input v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_srcTex, 0);

// u_postParams: x=strength (0..1), y=radius (0..1, falloff start)
uniform vec4 u_postParams;

void main()
{
    vec2 uv       = v_texcoord0.xy;
    vec3 col      = texture2D(s_srcTex, uv).rgb;

    float strength = u_postParams.x;
    float radius   = u_postParams.y; // 0.75 is a good default

    // Distance from centre in [0..1] range (circular)
    vec2  centered = uv * 2.0 - 1.0;
    float dist     = length(centered);

    // Smooth falloff starting at `radius`, reaching full strength at 1.0
    float vignette = 1.0 - smoothstep(radius, 1.0, dist) * strength;

    gl_FragColor = vec4(col * vignette, 1.0);
}
