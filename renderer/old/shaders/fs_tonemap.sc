$input v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_hdrBuffer, 0);  // HDR scene color (linear)
SAMPLER2D(s_bloom,     1);  // bloom contribution (optional, white 1x1 if unused)

uniform vec4 u_tonemapParams;
// x = exposure
// y = bloom strength
// z = tonemapper select: 0=ACES, 1=Reinhard, 2=Uncharted2
// w = unused

// ── Tonemappers ───────────────────────────────────────────────

// ACES fitted curve (Narkowicz 2015)
vec3 tonemapACES(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// Simple Reinhard
vec3 tonemapReinhard(vec3 x) {
    return x / (x + vec3_splat(1.0));
}

// Uncharted 2 (Hable filmic)
vec3 uncharted2Partial(vec3 x) {
    float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}
vec3 tonemapUncharted2(vec3 color) {
    float W = 11.2;
    vec3 curr    = uncharted2Partial(color * 2.0);
    vec3 whiteScale = vec3_splat(1.0) / uncharted2Partial(vec3_splat(W));
    return curr * whiteScale;
}

// ── Gamma ─────────────────────────────────────────────────────
vec3 linearToSRGB(vec3 color) {
    // Precise piecewise sRGB transfer function
    vec3 lo = color * 12.92;
    vec3 hi = 1.055 * pow(clamp(color, 0.0, 1.0), vec3_splat(1.0 / 2.4)) - 0.055;
    return mix(lo, hi, step(vec3_splat(0.0031308), color));
}

// ── Luminance for bloom ───────────────────────────────────────
float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main()
{
    vec2 uv = v_texcoord0;

    vec3 hdr   = texture2D(s_hdrBuffer, uv).rgb;
    vec3 bloom = texture2D(s_bloom,     uv).rgb;

    // Apply exposure
    float exposure = u_tonemapParams.x;
    hdr *= exposure;

    // Add bloom
    float bloomStrength = u_tonemapParams.y;
    hdr += bloom * bloomStrength;

    // Tonemap
    vec3 ldr;
    int tonemapper = int(u_tonemapParams.z);
    if (tonemapper == 1) {
        ldr = tonemapReinhard(hdr);
    } else if (tonemapper == 2) {
        ldr = tonemapUncharted2(hdr);
    } else {
        ldr = tonemapACES(hdr);  // default
    }

    // Gamma correct to sRGB
    vec3 srgb = linearToSRGB(ldr);

    gl_FragColor = vec4(srgb, 1.0);
}
