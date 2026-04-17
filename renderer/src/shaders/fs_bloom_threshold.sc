$input v_texcoord0
$output o_color

#include <bgfx_shader.sh>

uniform vec4 u_threshold;

SAMPLER2D(s_graphInput0, 0);

void main()
{
    vec4 color = texture2D(s_graphInput0, v_texcoord0);
    
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float threshold = u_threshold.x;
    
    if (brightness > threshold) {
        gl_FragColor = color * ((brightness - threshold) / brightness);
    } else {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
