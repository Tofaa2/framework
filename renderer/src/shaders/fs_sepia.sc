$input v_texcoord0
$output o_color

#include <bgfx_shader.sh>

uniform vec4 u_sepiaIntensity;

SAMPLER2D(s_texColor, 0);

void main()
{
    vec4 color = texture2D(s_texColor, v_texcoord0);
    
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 sepia = vec3(gray * 1.2, gray * 1.0, gray * 0.8);
    
    float intensity = u_sepiaIntensity.x;
    vec3 final = mix(color.rgb, sepia, intensity);
    
    gl_FragColor = vec4(final, color.a);
}
