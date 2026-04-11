vec3 a_position   : POSITION;
vec4 a_color0     : COLOR0;
vec2 a_texcoord0  : TEXCOORD0;
vec3 a_normal     : NORMAL;
vec4 a_tangent    : TANGENT;   // xyz = tangent, w = handedness

vec4 v_color0     : COLOR0;
vec2 v_texcoord0  : TEXCOORD0;
vec3 v_normal     : TEXCOORD1;
vec3 v_world_pos  : TEXCOORD2;

vec3 v_worldPos   : TEXCOORD3;
vec3 v_tangent    : TEXCOORD4;
vec3 v_bitangent  : TEXCOORD5;
