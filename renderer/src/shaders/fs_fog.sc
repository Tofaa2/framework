$input v_texcoord0

#include <bgfx_shader.sh>

uniform vec4 u_fogParams;
uniform vec4 u_fogColor;

SAMPLER2D(s_texColor, 0);

void main()
{
    vec4 color = texture2D(s_texColor, v_texcoord0);
    gl_FragColor = color;
}
