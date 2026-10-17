shader_type canvas_item;
// Full-screen dissolve. progress 0 = scene visible, 1 = fully covered.
// Blocky noise decides which pixels dissolve first; a glowing edge rides the front.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.02, 0.03, 0.08, 1.0);
uniform vec4 edge_color : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform float edge_width = 0.07;
uniform float cell_size = 12.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / cell_size);
	float n = 0.65 * vnoise(cell * 0.12) + 0.35 * hash(cell);
	float th = progress * (1.0 + edge_width);
	if (n < th - edge_width) {
		COLOR = fill_color;
	} else if (n < th) {
		COLOR = edge_color;
	} else {
		COLOR = vec4(0.0);
	}
}
