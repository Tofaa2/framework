$input v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_srcTex, 0);

// u_postParams: x=1/screenW (texel width), y=1/screenH (texel height)
uniform vec4 u_postParams;

// FXAA 3.11 — simplified quality preset
// Based on Timothy Lottes' FXAA whitepaper.
//
// Key ideas:
//   1. Detect edges using local luminance contrast
//   2. Find the length of the edge in both directions along it
//   3. Blend across the edge proportional to where we are along it

float fxaaLuma(vec3 rgb)
{
    return rgb.y * (0.587 / 0.299) + rgb.x;
}

void main()
{
    vec2 uv    = v_texcoord0.xy;
    vec2 texel = u_postParams.xy;

    // Sample centre and cardinal neighbours
    vec3 rgbN  = texture2D(s_srcTex, uv + vec2( 0.0, -texel.y)).rgb;
    vec3 rgbS  = texture2D(s_srcTex, uv + vec2( 0.0,  texel.y)).rgb;
    vec3 rgbE  = texture2D(s_srcTex, uv + vec2( texel.x,  0.0)).rgb;
    vec3 rgbW  = texture2D(s_srcTex, uv + vec2(-texel.x,  0.0)).rgb;
    vec3 rgbM  = texture2D(s_srcTex, uv).rgb;

    float lumaN = fxaaLuma(rgbN);
    float lumaS = fxaaLuma(rgbS);
    float lumaE = fxaaLuma(rgbE);
    float lumaW = fxaaLuma(rgbW);
    float lumaM = fxaaLuma(rgbM);

    float lumaMin = min(lumaM, min(min(lumaN, lumaS), min(lumaE, lumaW)));
    float lumaMax = max(lumaM, max(max(lumaN, lumaS), max(lumaE, lumaW)));
    float lumaRange = lumaMax - lumaMin;

    // Skip flat areas — no aliasing here
    const float FXAA_EDGE_THRESHOLD     = 0.166; // 1/6
    const float FXAA_EDGE_THRESHOLD_MIN = 0.0833;
    if (lumaRange < max(FXAA_EDGE_THRESHOLD_MIN, lumaMax * FXAA_EDGE_THRESHOLD))
    {
        gl_FragColor = vec4(rgbM, 1.0);
        return;
    }

    // Sample diagonals to determine edge direction
    vec3 rgbNW = texture2D(s_srcTex, uv + vec2(-texel.x, -texel.y)).rgb;
    vec3 rgbNE = texture2D(s_srcTex, uv + vec2( texel.x, -texel.y)).rgb;
    vec3 rgbSW = texture2D(s_srcTex, uv + vec2(-texel.x,  texel.y)).rgb;
    vec3 rgbSE = texture2D(s_srcTex, uv + vec2( texel.x,  texel.y)).rgb;

    float lumaNW = fxaaLuma(rgbNW);
    float lumaNE = fxaaLuma(rgbNE);
    float lumaSW = fxaaLuma(rgbSW);
    float lumaSE = fxaaLuma(rgbSE);

    float edgeH = abs(lumaNW + 2.0*lumaN + lumaNE - lumaSW - 2.0*lumaS - lumaSE);
    float edgeV = abs(lumaNW + 2.0*lumaW + lumaSW - lumaNE - 2.0*lumaE - lumaSE);

    bool  isHorizontal = (edgeH >= edgeV);
    float stepLength   = isHorizontal ? texel.y : texel.x;

    float luma1 = isHorizontal ? lumaS : lumaE;
    float luma2 = isHorizontal ? lumaN : lumaW;
    float gradient1 = abs(luma1 - lumaM);
    float gradient2 = abs(luma2 - lumaM);
    bool  steepest = (gradient1 >= gradient2);
    stepLength = steepest ? -stepLength : stepLength;
    float lumaLocalAvg = steepest
        ? 0.5 * (luma1 + lumaM)
        : 0.5 * (luma2 + lumaM);

    // Walk along edge in both directions to find its extent
    vec2 currentUV = isHorizontal
        ? vec2(uv.x, uv.y + stepLength * 0.5)
        : vec2(uv.x + stepLength * 0.5, uv.y);

    vec2 offset = isHorizontal ? vec2(texel.x, 0.0) : vec2(0.0, texel.y);
    const int SEARCH_STEPS = 8;
    const float SEARCH_SPEED = 1.5;

    vec2 uv1 = currentUV - offset * SEARCH_SPEED;
    vec2 uv2 = currentUV + offset * SEARCH_SPEED;
    float lumaEnd1 = fxaaLuma(texture2D(s_srcTex, uv1).rgb) - lumaLocalAvg;
    float lumaEnd2 = fxaaLuma(texture2D(s_srcTex, uv2).rgb) - lumaLocalAvg;
    bool done1 = abs(lumaEnd1) >= gradient1 * 0.25;
    bool done2 = abs(lumaEnd2) >= gradient1 * 0.25;

    for (int i = 0; i < SEARCH_STEPS; ++i)
    {
        if (!done1) { uv1 -= offset * SEARCH_SPEED; lumaEnd1 = fxaaLuma(texture2D(s_srcTex, uv1).rgb) - lumaLocalAvg; }
        if (!done2) { uv2 += offset * SEARCH_SPEED; lumaEnd2 = fxaaLuma(texture2D(s_srcTex, uv2).rgb) - lumaLocalAvg; }
        done1 = done1 || (abs(lumaEnd1) >= gradient1 * 0.25);
        done2 = done2 || (abs(lumaEnd2) >= gradient1 * 0.25);
        if (done1 && done2) break;
    }

    // Compute sub-pixel blend amount
    float dst1 = isHorizontal ? (uv.x - uv1.x) : (uv.y - uv1.y);
    float dst2 = isHorizontal ? (uv2.x - uv.x) : (uv2.y - uv.y);
    bool  dir1 = dst1 < dst2;
    float lumaEndFinal = dir1 ? lumaEnd1 : lumaEnd2;
    float dstFinal     = min(dst1, dst2);
    float spanLength   = dst1 + dst2;

    bool  goodSpan  = ((lumaM - lumaLocalAvg) < 0.0) != (lumaEndFinal < 0.0);
    float blendFinal = goodSpan ? (0.5 - dstFinal / spanLength) : 0.0;

    // Sub-pixel alias correction
    float lumaAvg = (1.0/12.0) * (
        2.0*(lumaN+lumaS+lumaE+lumaW) + lumaNW+lumaNE+lumaSW+lumaSE);
    float subBlend = clamp(
        abs(lumaAvg - lumaM) / lumaRange * 2.0 - 0.5,
        0.0, 1.0);
    subBlend = subBlend * subBlend * 0.75;
    blendFinal = max(blendFinal, subBlend);

    vec2 finalUV = isHorizontal
        ? vec2(uv.x, uv.y + blendFinal * stepLength)
        : vec2(uv.x + blendFinal * stepLength, uv.y);

    gl_FragColor = vec4(texture2D(s_srcTex, finalUV).rgb, 1.0);
}
