$input a_position
$output v_texcoord0

#include <bgfx_shader.sh>

void main()
{
    // Fullscreen triangle trick: generate a triangle that covers the screen
    // using only the vertex index — no vertex buffer required.
    //
    //  v0: (-1, -1)  v1: ( 3, -1)  v2: (-1,  3)
    //
    // This avoids the diagonal seam you'd get with two triangles, and
    // skips the overhead of uploading vertex data every frame.

    float x = float((gl_VertexID & 1) << 2) - 1.0;
    float y = float((gl_VertexID & 2) << 1) - 1.0;

    v_texcoord0.x = x * 0.5 + 0.5;
    v_texcoord0.y = 1.0 - (y * 0.5 + 0.5); // flip Y for bgfx UV convention

    gl_Position = vec4(x, y, 0.0, 1.0);
}
