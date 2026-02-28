$input v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_srcTex, 0);

// u_postParams: x=exposure
uniform vec4 u_postParams;

// ACES filmic tonemapping approximation by Krzysztof Narkowicz
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
// Input: linear HDR colour. Output: [0..1] LDR colour.
vec3 aces(vec3 x)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// Simple gamma correction (linear → sRGB approximation)
vec3 linearToSrgb(vec3 c)
{
    return pow(c, vec3_splat(1.0 / 2.2));
}

void main()
{
    vec2 uv       = v_texcoord0.xy;
    vec3 hdr      = texture2D(s_srcTex, uv).rgb;
    float exposure = u_postParams.x;

    // Apply exposure, tonemap, then gamma-correct
    vec3 ldr = aces(hdr * exposure);
    ldr      = linearToSrgb(ldr);

    gl_FragColor = vec4(ldr, 1.0);
}
