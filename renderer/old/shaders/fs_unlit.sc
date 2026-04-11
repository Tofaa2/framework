$input v_color0, v_texcoord0, v_normal, v_world_pos

#include <bgfx_shader.sh>

SAMPLER2D(s_texColor, 0);

uniform vec4 u_baseColor;

void main()
{
    vec4 tex    = texture2D(s_texColor, v_texcoord0);
    vec4 result = tex * v_color0 * u_baseColor;

    if (result.a < 0.01) discard;

    gl_FragColor = result;
}
