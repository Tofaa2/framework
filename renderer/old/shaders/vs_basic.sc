$input a_position, a_color0, a_texcoord0, a_normal
$output v_color0, v_texcoord0, v_normal, v_world_pos

#include <bgfx_shader.sh>

void main()
{
    vec4 world_pos = mul(u_model[0], vec4(a_position, 1.0));
    gl_Position    = mul(u_viewProj, world_pos);

    v_world_pos  = world_pos.xyz;
    v_color0     = a_color0;
    v_texcoord0  = a_texcoord0;

    // Transform normal into world space (no non-uniform scale assumed)
    v_normal = normalize(mul(u_model[0], vec4(a_normal, 0.0)).xyz);
}
