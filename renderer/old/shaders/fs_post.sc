$input v_texcoord0

#include <bgfx_shader.sh>

// ============================================================
// POST-PROCESSING SHADER
// ============================================================
// This shader applies various effects to the rendered scene.
// 
// ADDING NEW EFFECTS:
// 1. Add a new uniform in the "Uniforms" section below
// 2. Create the uniform in sandbox.zig with Material.setVec4()
// 3. Apply your effect in main() after sampling the texture
//
// EFFECTS ORDER MATTERS:
// - Effects are applied in order from top to bottom
// - Changing order can significantly change the final look
// ============================================================

// Uniforms - control post-processing parameters
// u_exposure: x=exposure, y=vignette strength (0-1)
uniform vec4 u_exposure;

// Textures - s_sceneColor is the rendered scene from the framebuffer
SAMPLER2D(s_sceneColor, 0);

void main()
{
    vec2 uv = v_texcoord0;
    
    // ========================================
    // 1. SAMPLE THE SCENE
    // ========================================
    vec4 color = texture2D(s_sceneColor, uv);
    
    // ========================================
    // 2. APPLY YOUR EFFECTS HERE
    // ========================================
    // Examples:
    
    // --- Exposure (brightness) ---
    color.rgb *= u_exposure.x;
    
    // --- Tone Mapping (HDR compression) ---
    color.rgb = color.rgb / (1.0 + color.rgb);
    
    // --- Vignette (darkens edges) ---
    vec2 center = vec2(0.5, 0.5);
    float dist = length(uv - center);
    float vignette = 1.0 - dist * u_exposure.y * 2.0;
    vignette = clamp(vignette, 0.0, 1.0);
    vignette = vignette * vignette;
    color.rgb *= vignette;
    
    // --- Color Grading (tint the scene) ---
    // color.rgb *= vec3(1.0, 0.95, 0.9);  // Warm tint
    // color.rgb *= vec3(0.9, 0.95, 1.0);  // Cool tint
    
    // --- Contrast ---
    // color.rgb = (color.rgb - 0.5) * contrast + 0.5;
    
    // --- Saturation ---
    // float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    // color.rgb = mix(vec3(luminance), color.rgb, saturation);
    
    // --- Chromatic Aberration ---
    // float aberration = 0.003;
    // color.r = texture2D(s_sceneColor, uv + (uv - center) * aberration).r;
    // color.b = texture2D(s_sceneColor, uv - (uv - center) * aberration).b;
    
    // --- Film Grain ---
    // float grain = (fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.1;
    // color.rgb += grain;
    
    // --- Scanlines ---
    // color.rgb *= 0.95 + 0.05 * sin(uv.y * 800.0);
    
    // ========================================
    // 3. GAMMA CORRECTION (ALWAYS LAST)
    // ========================================
    // Must be last to output correct color
    color.r = pow(color.r, 0.4545);
    color.g = pow(color.g, 0.4545);
    color.b = pow(color.b, 0.4545);
    
    gl_FragColor = color;
}
