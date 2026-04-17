$input v_texcoord0
$output o_color

#include <bgfx_shader.sh>

uniform vec4 u_blurParams;

SAMPLER2D(s_graphInput0, 0);

void main()
{
    vec2 texelSize = vec2(1.0 / 1920.0, 1.0 / 1080.0);
    vec2 direction = u_blurParams.xy;
    float intensity = u_blurParams.z;
    
    vec4 result = vec4(0.0, 0.0, 0.0, 0.0);
    
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * -4.0) * 0.0162162162;
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * -3.0) * 0.0540540541;
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * -2.0) * 0.1216216216;
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * -1.0) * 0.1945945946;
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * 0.0) * 0.2270270270;
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * 1.0) * 0.1945945946;
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * 2.0) * 0.1216216216;
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * 3.0) * 0.0540540541;
    result += texture2D(s_graphInput0, v_texcoord0 + texelSize * direction * 4.0) * 0.0162162162;
    
    gl_FragColor = result * intensity;
}
