$input v_texcoord0
$output o_color

#include <bgfx_shader.sh>

uniform vec4 u_tonemapParams;

SAMPLER2D(s_texColor, 0);

vec3 tonemapACES(vec3 x)
{
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    float r = (x.r * (a * x.r + b)) / (x.r * (c * x.r + d) + e);
    float g = (x.g * (a * x.g + b)) / (x.g * (c * x.g + d) + e);
    float bb = (x.b * (a * x.b + b)) / (x.b * (c * x.b + d) + e);
    return vec3(r, g, bb);
}

void main()
{
    vec4 color = texture2D(s_texColor, v_texcoord0);
    vec3 hdr = color.rgb * 2.0;
    
    float mode = u_tonemapParams.y;
    
    if (mode < 0.5) {
        vec3 mapped = tonemapACES(hdr);
        gl_FragColor = vec4(mapped, 1.0);
    } else if (mode < 1.5) {
        float r = hdr.r / (hdr.r + 1.0);
        float g = hdr.g / (hdr.g + 1.0);
        float b = hdr.b / (hdr.b + 1.0);
        gl_FragColor = vec4(r, g, b, 1.0);
    } else {
        gl_FragColor = color;
    }
}
