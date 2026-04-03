$input v_color0, v_texcoord0, v_normal

#include <bgfx_shader.sh>

SAMPLER2D(s_texColor, 0);

uniform vec4 u_lightDirs[4];
uniform vec4 u_lightColors[4];
uniform vec4 u_lightCount;
uniform vec4 u_ambient;

void main()
{
    vec3 normal = normalize(v_normal);

    vec3 lighting = u_ambient.rgb;
    int count = int(u_lightCount.x);
    for (int i = 0; i < count; i++) {
        vec3 light_dir = normalize(-u_lightDirs[i].xyz);
        float diff = max(dot(normal, light_dir), 0.0);
        lighting += u_lightColors[i].rgb * diff;
    }

    vec4 tex_color = texture2D(s_texColor, v_texcoord0);
    gl_FragColor = vec4(lighting * tex_color.rgb * v_color0.rgb, tex_color.a * v_color0.a);
}
