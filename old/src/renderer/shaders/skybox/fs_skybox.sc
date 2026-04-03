$input v_dir

#include <bgfx_shader.sh>

SAMPLERCUBE(s_cubemap, 0);

void main() {
    gl_FragColor = textureCube(s_cubemap, v_dir);
}
