$input v_texcoord0
$output o_color

#include <bgfx_shader.sh>

uniform vec4 u_bloomIntensity;

SAMPLER2D(s_graphInput0, 0);
SAMPLER2D(s_graphInput1, 1);

void main()
{
    vec4 scene = texture2D(s_graphInput0, v_texcoord0);
    vec4 bloom = texture2D(s_graphInput1, v_texcoord0);
    
    float intensity = u_bloomIntensity.x;
    
    gl_FragColor = scene + bloom * intensity;
}
