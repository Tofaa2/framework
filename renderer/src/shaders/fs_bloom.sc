$input v_texcoord0
$output o_color

#include <bgfx_shader.sh>

uniform vec4 u_bloomParams;

SAMPLER2D(s_texColor, 0);

void main()
{
    vec4 color = texture2D(s_texColor, v_texcoord0);
    
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    
    float threshold = u_bloomParams.x;
    float intensity = u_bloomParams.y;
    
    vec3 cyan = vec3(0.0, 1.0, 1.0);
    vec3 final = color.rgb;
    
    if (brightness > threshold) {
        float glow = (brightness - threshold) * intensity;
        final = mix(color.rgb, cyan, glow);
        final += cyan * glow * 2.0;
    }
    
    gl_FragColor = vec4(final, color.a);
}
