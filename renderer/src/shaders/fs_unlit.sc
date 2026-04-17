$input v_normal, v_pos, v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_texColor, 0);

uniform vec4 u_color;
uniform vec4 u_useTexture;

void main()
{
    vec4 base = u_color;
    if (u_useTexture.x > 0.5)
    {
        base *= texture2D(s_texColor, v_texcoord0);
    }
    gl_FragColor = base;
}
