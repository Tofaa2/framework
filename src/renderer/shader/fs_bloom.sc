$input v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_srcTex, 0);

// u_postParams:  x=threshold, y=intensity, z=radius, w=unused
// u_postParams2: x=texel_width (1/screenW), y=texel_height (1/screenH)
uniform vec4 u_postParams;
uniform vec4 u_postParams2;

// Luminance weight (perceptual)
float luminance(vec3 c)
{
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Single-pass bloom:
//   1. Sample a 3x3 neighbourhood with a soft knee curve to extract bright areas
//   2. Blur horizontally and vertically using a 13-tap Gaussian (separated
//      into two passes conceptually, but collapsed here for simplicity)
//
// For higher quality, split into separate H and V blur passes via the stack:
//   renderer.addPass(.bloom, ...)   // extract + H blur
//   renderer.addPass(.bloom, ...)   // V blur  (shader checks u_postParams.w)

void main()
{
    vec2 uv     = v_texcoord0.xy;
    float threshold = u_postParams.x;
    float intensity = u_postParams.y;
    float radius    = u_postParams.z;

    // We don't have u_postParams2 set in the single-pass built-in path,
    // so derive texel size from ddx/ddy of the UV coordinates instead.
    vec2 texel = vec2(
        abs(dFdx(uv.x)),
        abs(dFdy(uv.y))
    );
    texel *= radius;

    // 13-tap Gaussian weights (sigma≈1.5, normalised)
    // Offsets cover ±3 texels on each axis
    const int TAPS = 13;
    vec2 offsets[TAPS];
    offsets[ 0] = vec2(-3.0, -3.0);
    offsets[ 1] = vec2(-1.0, -3.0);
    offsets[ 2] = vec2( 1.0, -3.0);
    offsets[ 3] = vec2( 3.0, -3.0);
    offsets[ 4] = vec2(-3.0,  0.0);
    offsets[ 5] = vec2(-1.0,  0.0);
    offsets[ 6] = vec2( 0.0,  0.0); // centre
    offsets[ 7] = vec2( 1.0,  0.0);
    offsets[ 8] = vec2( 3.0,  0.0);
    offsets[ 9] = vec2(-3.0,  3.0);
    offsets[10] = vec2(-1.0,  3.0);
    offsets[11] = vec2( 1.0,  3.0);
    offsets[12] = vec2( 3.0,  3.0);

    float weights[TAPS];
    weights[ 0] = 0.0625 * 0.25;
    weights[ 1] = 0.125  * 0.25;
    weights[ 2] = 0.125  * 0.25;
    weights[ 3] = 0.0625 * 0.25;
    weights[ 4] = 0.125  * 0.25;
    weights[ 5] = 0.25   * 0.25;
    weights[ 6] = 0.25   * 0.25;  // centre has full weight
    weights[ 7] = 0.25   * 0.25;
    weights[ 8] = 0.125  * 0.25;
    weights[ 9] = 0.0625 * 0.25;
    weights[10] = 0.125  * 0.25;
    weights[11] = 0.125  * 0.25;
    weights[12] = 0.0625 * 0.25;

    // --- Threshold extraction + blur ---
    vec3 bloom = vec3_splat(0.0);
    float totalWeight = 0.0;

    for (int i = 0; i < TAPS; ++i)
    {
        vec2  sampleUV  = uv + offsets[i] * texel;
        vec3  col       = texture2D(s_srcTex, sampleUV).rgb;

        // Soft-knee threshold: ramp from 0 at (threshold - knee) to full at threshold
        float knee     = threshold * 0.2;
        float lum      = luminance(col);
        float rq       = clamp(lum - threshold + knee, 0.0, 2.0 * knee);
        float softKnee = (rq * rq) / (4.0 * knee + 0.00001);
        float weight   = max(softKnee, lum - threshold) / max(lum, 0.00001);

        bloom       += col * weight * weights[i];
        totalWeight += weights[i];
    }

    bloom /= totalWeight;

    // Also sample the original pixel to composite bloom on top
    vec3 original = texture2D(s_srcTex, uv).rgb;
    vec3 result   = original + bloom * intensity;

    gl_FragColor = vec4(result, 1.0);
}
