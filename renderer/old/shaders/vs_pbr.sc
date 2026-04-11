$input a_position, a_color0, a_texcoord0, a_normal, a_tangent
$output v_color0, v_texcoord0, v_normal, v_worldPos, v_tangent

#include <bgfx_shader.sh>

void main()
{
    vec4 worldPos = mul(u_model[0], vec4(a_position, 1.0));
    gl_Position = mul(u_viewProj, worldPos);

    v_worldPos  = worldPos.xyz;
    v_color0    = a_color0;
    v_texcoord0 = a_texcoord0;
    v_normal    = normalize(mul(u_model[0], vec4(a_normal, 0.0)).xyz);
    v_tangent   = normalize(mul(u_model[0], vec4(a_tangent.xyz, 0.0)).xyz);
}
