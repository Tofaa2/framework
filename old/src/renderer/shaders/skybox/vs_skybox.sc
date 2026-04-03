$input a_position
$output v_dir

#include <bgfx_shader.sh>

void main() {
    mat4 view_rot = u_view;
    view_rot[3][0] = 0.0;
    view_rot[3][1] = 0.0;
    view_rot[3][2] = 0.0;
    vec4 pos = mul(u_proj, mul(view_rot, vec4(a_position, 1.0)));
    gl_Position = pos.xyww;
    v_dir = a_position;
}
