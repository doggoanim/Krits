shader_type canvas_item;
// Full-screen dissolve. progress 0 = scene visible, 1 = fully covered.
// A few octaves of smooth value noise (fbm) decide which pixels dissolve first —
// a continuous, flowing field rather than a grid of uniform blocks, so the edge
// reads as an organic burn line (think Balatro's card-dissolve) instead of
// pixelated chunks. A bright edge rides the front of the wipe.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.96, 0.96, 0.98, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float edge_width = 0.07;
uniform float noise_scale = 7.0;   // smaller = larger, slower-flowing noise features

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

// Layering a few octaves of the smooth noise above (each one finer and fainter)
// is what keeps the dissolve edge organic/wavy instead of a hard-edged grid.
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p *= 2.05;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	float n = fbm(FRAGCOORD.xy / (noise_scale * 16.0));
	float th = progress * (1.0 + edge_width);
	if (n < th - edge_width) {
		COLOR = fill_color;
	} else if (n < th) {
		COLOR = edge_color;
	} else {
		COLOR = vec4(0.0);
	}
}
