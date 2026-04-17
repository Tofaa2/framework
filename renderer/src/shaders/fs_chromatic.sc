$input v_texcoord0
$output o_color

#include <bgfx_shader.sh>

uniform vec4 u_waveParams;

SAMPLER2D(s_texColor, 0);

void main()
{
    vec2 uv = v_texcoord0;
    float strength = u_waveParams.x;
    float speed = u_waveParams.y;
    float time = u_waveParams.z;
    
    uv.x += sin(uv.y * 20.0 + time * speed) * strength;
    uv.y += cos(uv.x * 20.0 + time * speed) * strength;
    
    vec4 color = texture2D(s_texColor, uv);
    gl_FragColor = color;
}
