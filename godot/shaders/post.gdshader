shader_type canvas_item;
// Screen overlay: soft vignette and a little film grain. Sits under the HUD.

uniform float vignette = 0.45;
uniform float vignette_soft = 0.55;
uniform vec3 vignette_color : source_color = vec3(0.0);
uniform float grain = 0.035;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.75;
	float d = length(uv) * 1.35;
	float v = smoothstep(1.0 - vignette_soft, 1.25, d) * vignette;
	float g = (hash(FRAGCOORD.xy + fract(TIME * 7.13) * 91.7) - 0.5) * grain;
	// darken toward the edges, grain everywhere; alpha carries the darkening
	COLOR = vec4(vignette_color + vec3(g), clamp(v + abs(g), 0.0, 1.0));
}
