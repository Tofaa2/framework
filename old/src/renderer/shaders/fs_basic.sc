$input v_color0, v_texcoord0, v_normal

#include <bgfx_shader.sh>

SAMPLER2D(s_texColor, 0);

void main()
{
vec4 tex_color = texture2D(s_texColor, v_texcoord0);
if (tex_color.a < 0.1) discard;
gl_FragColor = vec4(tex_color.rgb * v_color0.rgb, tex_color.a * v_color0.a);

  //    gl_FragColor = texture2D(s_texColor, v_texcoord0) * v_color0;
}
