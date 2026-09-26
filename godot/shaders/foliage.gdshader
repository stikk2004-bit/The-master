shader_type spatial;
// Leaf, needle, moss and grass cards. Cut out by alpha, lit from both sides,
// glowing a little when the light comes through from behind, and moving in the wind.
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D card_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut = 0.45;
uniform float wind = 0.06;           // meters of sway at the card's top
uniform float wind_speed = 1.1;
uniform float anchor_bottom = 0.0;   // 1 for grass and moss: pinned at one edge
uniform float anchor_top = 0.0;
uniform float translucency = 0.35;
uniform float roughness = 0.7;
uniform float variation = 0.18;

varying vec3 w_pos;
varying float vary;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vary = hash(origin.xz + origin.y);
	float free = 1.0;
	if (anchor_bottom > 0.0) {
		free = clamp(1.0 - UV.y, 0.0, 1.0);
	} else if (anchor_top > 0.0) {
		free = clamp(UV.y, 0.0, 1.0);
	}
	float t = TIME * wind_speed + vary * 6.28;
	float gust = 0.6 + 0.4 * sin(TIME * 0.37 + wp.x * 0.05);
	vec3 sway = vec3(sin(t + wp.x * 0.4), 0.0, cos(t * 0.8 + wp.z * 0.4)) * wind * gust * free;
	sway.y = -abs(sway.x) * 0.2;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(sway, 0.0)).xyz;
	w_pos = wp;
}

void fragment() {
	vec4 c = texture(card_tex, UV);
	if (c.a < alpha_cut) {
		discard;
	}
	vec3 col = c.rgb * tint.rgb;
	col *= 1.0 + (vary - 0.5) * 2.0 * variation;
	ALBEDO = col;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	BACKLIGHT = col * translucency;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
