shader_type spatial;
// World surfaces: stone, wood, plaster, metal, ground.
// Textures are projected from three sides (triplanar), so models need no UV unwrap,
// and scale stays true to real meters no matter how a mesh was built.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform vec4 tint : source_color = vec4(1.0);
uniform float tile_meters = 2.0;          // one texture repeat covers this many meters
uniform float normal_strength = 1.0;
uniform float rough_scale = 1.0;
uniform float rough_offset = 0.0;
uniform float metal_scale = 1.0;
uniform float ao_strength = 1.0;
uniform float macro_strength = 0.22;      // big soft light/dark patches that hide tiling
uniform float grime_strength = 0.35;      // dirt that climbs up from the floor
uniform float grime_height = 0.9;
uniform float moss_amount = 0.0;          // green on the tops of things, outdoors
uniform vec4 moss_color : source_color = vec4(0.16, 0.2, 0.08, 1.0);
uniform float dust_amount = 0.0;          // pale dust settled on upward faces, indoors
uniform bool object_space = false;        // true for props that move, so the texture rides along
uniform bool vertical_grain = false;      // turn wood grain upright on posts and trunks
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float blend_sharpness = 6.0;

global uniform float ground_y;

varying vec3 tp_pos;
varying vec3 tp_nrm;
varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (object_space) {
		tp_pos = VERTEX;
		tp_nrm = NORMAL;
	} else {
		tp_pos = w_pos;
		tp_nrm = w_nrm;
	}
}

vec2 grain(vec2 uv) {
	// quarter turn: grain that ran across now runs up
	return vertical_grain ? vec2(-uv.y, uv.x) : uv;
}

void fragment() {
	vec3 n = normalize(tp_nrm);
	vec3 w = pow(abs(n), vec3(blend_sharpness));
	w /= (w.x + w.y + w.z);
	vec3 p = tp_pos / tile_meters;
	vec3 sg = vec3(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0, n.z >= 0.0 ? 1.0 : -1.0);

	// Each plane is laid so the picture reads the right way up and never mirrored,
	// as if you stood facing that side. Texture up is world up on walls.
	vec2 uv_x = grain(vec2(-p.z * sg.x, -p.y));
	vec2 uv_y = vec2(p.x * sg.y, p.z) + vec2(0.37, 0.21);
	vec2 uv_z = grain(vec2(p.x * sg.z, -p.y)) + vec2(0.53, 0.0);

	vec3 a_x = texture(albedo_tex, uv_x).rgb;
	vec3 a_y = texture(albedo_tex, uv_y).rgb;
	vec3 a_z = texture(albedo_tex, uv_z).rgb;
	vec3 alb = a_x * w.x + a_y * w.y + a_z * w.z;

	vec3 o_x = texture(orm_tex, uv_x).rgb;
	vec3 o_y = texture(orm_tex, uv_y).rgb;
	vec3 o_z = texture(orm_tex, uv_z).rgb;
	vec3 orm = o_x * w.x + o_y * w.y + o_z * w.z;

	// whiteout-blended triplanar normals (after Ben Golus), each map turned into its plane's frame
	vec3 t_x = texture(normal_tex, uv_x).rgb * 2.0 - 1.0;
	vec3 t_y = texture(normal_tex, uv_y).rgb * 2.0 - 1.0;
	vec3 t_z = texture(normal_tex, uv_z).rgb * 2.0 - 1.0;
	if (vertical_grain) {
		t_x.xy = vec2(-t_x.y, t_x.x);
		t_z.xy = vec2(-t_z.y, t_z.x);
	}
	t_x.xy *= normal_strength;
	t_y.xy *= normal_strength;
	t_z.xy *= normal_strength;
	t_x.x *= -sg.x;
	t_y.x *= sg.y;
	t_y.y = -t_y.y;
	t_z.x *= sg.z;
	vec3 nx = vec3(t_x.xy + n.zy, abs(t_x.z) * n.x);
	vec3 ny = vec3(t_y.xy + n.xz, abs(t_y.z) * n.y);
	vec3 nz = vec3(t_z.xy + n.xy, abs(t_z.z) * n.z);
	vec3 nb = normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
	if (object_space) {
		nb = normalize((MODEL_MATRIX * vec4(nb, 0.0)).xyz);
	}

	// big soft variation in world space so repeats don't read as a grid
	vec3 mac = texture(macro_tex, w_pos.xz * 0.045 + vec2(w_pos.y * 0.03)).rgb;
	float macro = mix(1.0 - macro_strength, 1.0 + macro_strength * 0.6, mac.r * 0.7 + mac.g * 0.3);
	alb *= tint.rgb * macro;

	// grime climbing from the floor
	float h = w_pos.y - ground_y;
	float grime = (1.0 - smoothstep(0.0, grime_height, h)) * grime_strength * (0.6 + 0.8 * mac.b);
	alb *= 1.0 - grime * (1.0 - abs(w_nrm.y) * 0.7);

	float up = clamp(w_nrm.y, 0.0, 1.0);
	float moss = moss_amount * smoothstep(0.35, 0.85, up) * smoothstep(0.35, 0.65, mac.g + (orm.r - 0.5) * 0.4);
	alb = mix(alb, moss_color.rgb * (0.7 + 0.6 * mac.r), clamp(moss, 0.0, 1.0));
	float dust = dust_amount * smoothstep(0.6, 0.95, up) * (0.5 + 0.5 * mac.g);
	alb = mix(alb, vec3(0.42, 0.39, 0.35), clamp(dust, 0.0, 1.0));

	ALBEDO = alb;
	ROUGHNESS = clamp(orm.g * rough_scale + rough_offset + moss * 0.3 + dust * 0.3, 0.02, 1.0);
	METALLIC = clamp(orm.b * metal_scale * (1.0 - moss), 0.0, 1.0);
	AO = mix(1.0, orm.r, ao_strength);
	AO_LIGHT_AFFECT = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(nb, 0.0)).xyz);
	EMISSION = emission_color * emission_energy;
}
