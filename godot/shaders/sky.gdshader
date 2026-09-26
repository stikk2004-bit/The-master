shader_type sky;
// Painted-looking sky: gradient, drifting cloud banks lit from the sun side, stars and a moon at night.

uniform vec3 zenith_color : source_color = vec3(0.05, 0.08, 0.14);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.42, 0.28);
uniform vec3 ground_color : source_color = vec3(0.06, 0.06, 0.05);
uniform vec3 cloud_lit : source_color = vec3(0.9, 0.62, 0.42);
uniform vec3 cloud_shade : source_color = vec3(0.16, 0.15, 0.17);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_speed = 0.004;
uniform float horizon_blend = 0.18;
uniform float sun_glow = 1.0;
uniform float stars = 0.0;
uniform vec3 moon_dir = vec3(-0.3, 0.45, -0.84);
uniform float moon_size = 0.0;
uniform float brightness = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float up = d.y;
	float t = clamp(up / horizon_blend, 0.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(t, 0.55));
	if (up < 0.0) {
		col = mix(horizon_color * 0.6, ground_color, clamp(-up * 6.0, 0.0, 1.0));
	}

	vec3 sd = LIGHT0_DIRECTION;
	float sun_amt = LIGHT0_ENABLED ? max(dot(d, sd), 0.0) : 0.0;
	vec3 sun_col = LIGHT0_ENABLED ? LIGHT0_COLOR * LIGHT0_ENERGY : vec3(0.0);
	col += sun_col * (pow(sun_amt, 8.0) * 0.35 + pow(sun_amt, 64.0) * 0.6 + pow(sun_amt, 900.0) * 6.0) * sun_glow;

	if (stars > 0.0 && up > 0.0) {
		vec2 sp = d.xz / (up + 0.3) * 180.0;
		float s = step(0.9965, hash(floor(sp)));
		float tw = 0.6 + 0.4 * sin(TIME * 3.0 + hash(floor(sp) + 3.1) * 40.0);
		col += vec3(0.85, 0.9, 1.0) * s * tw * stars * smoothstep(0.0, 0.25, up);
	}

	if (moon_size > 0.0) {
		vec3 md = normalize(moon_dir);
		float m = dot(d, md);
		float disc = smoothstep(1.0 - moon_size, 1.0 - moon_size * 0.9, m);
		vec2 mp = vec2(dot(d, normalize(cross(md, vec3(0, 1, 0)))), d.y - md.y) * 90.0;
		float craters = 0.82 + 0.18 * noise(mp * 1.7);
		col = mix(col, vec3(0.92, 0.93, 0.88) * craters * 1.4, disc);
		col += vec3(0.5, 0.55, 0.65) * pow(max(m, 0.0), 180.0) * 0.5;
	}

	if (up > -0.02) {
		vec2 cp = d.xz / (max(up, 0.0) + 0.12) * 0.9 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float c = fbm(cp);
		float c2 = fbm(cp * 2.3 + 5.0);
		float dens = smoothstep(1.0 - cloud_cover - 0.08, 1.0 - cloud_cover + 0.3, c * 0.75 + c2 * 0.35);
		float lit = clamp(0.35 + 0.65 * (fbm(cp + sd.xz * 0.35) - c + 0.5), 0.0, 1.0);
		float toward_sun = pow(sun_amt, 3.0);
		vec3 cc = mix(cloud_shade, cloud_lit, lit * (0.35 + 0.65 * toward_sun));
		float fade = smoothstep(-0.02, 0.12, up);
		col = mix(col, cc, dens * fade * 0.95);
	}

	COLOR = col * brightness;
}
