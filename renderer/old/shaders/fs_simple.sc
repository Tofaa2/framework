$input v_color0, v_texcoord0, v_normal

#include <bgfx_shader.sh>

SAMPLER2D(s_tex, 0);
uniform vec4 u_color;

void main()
{
    vec4 texColor = texture2D(s_tex, v_texcoord0);
    vec4 color = texColor * u_color;
    
    // Simple directional lighting
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.3));
    float diffuse = max(dot(normalize(v_normal), lightDir), 0.0);
    color.rgb = color.rgb * (0.5 + 0.5 * diffuse);
    
    gl_FragColor = color;
}
