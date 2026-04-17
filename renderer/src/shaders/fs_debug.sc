$input v_texcoord0
$output o_color

#include <bgfx_shader.sh>

uniform vec4 u_debugColor;

SAMPLER2D(s_texColor, 0);

void main()
{
    vec4 color = texture2D(s_texColor, v_texcoord0);
    
    float enabled = u_debugColor.w;
    
    if (enabled > 0.5) {
        gl_FragColor = u_debugColor;
    } else {
        gl_FragColor = color;
    }
}
