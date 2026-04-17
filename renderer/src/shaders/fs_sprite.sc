$input v_texcoord0, v_color0

#include <bgfx_shader.sh>

SAMPLER2D(s_texColor, 0);
uniform vec4 u_useTexture;

void main()
{
    vec4 col = v_color0;
    if (u_useTexture.x > 0.5)
    {
        col *= texture2D(s_texColor, v_texcoord0);
    }
    if (col.a < 0.01) discard;
    gl_FragColor = col;
}
