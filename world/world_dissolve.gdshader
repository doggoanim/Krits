shader_type spatial;
render_mode unshaded, cull_back;
// World-space dissolve: the geometry itself crumbles away into noise instead of a
// screen overlay fading over it. progress 0 = fully solid, 1 = fully dissolved away.
// A few octaves of smooth 3D value noise (fbm) drive the dissolve front — a
// continuous, flowing field rather than a grid of uniform blocks, so it reads as
// an organic burn/melt line (think Balatro's card-dissolve) instead of pixelated
// chunks. Each mesh keeps its own color via the per-instance `albedo_color`
// uniform (set by WorldDissolver), while every dissolving mesh shares the same
// noise field in world space, so the whole level breaks apart as one coherent
// wave rather than per-object.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 2.2;         // world units per noise feature
uniform float edge_width = 0.12;
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * vec3(123.34, 456.21, 789.19));
	p += dot(p, p + 45.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i);
	float n100 = hash(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

// Layering a few octaves of the smooth noise above (each one finer and fainter)
// is what keeps the dissolve front organic/wavy instead of a hard-edged grid.
float fbm(vec3 p) {
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
	float n = fbm(world_pos / noise_scale);
	// progress 0: th = 0, nothing discarded (n is always >= 0).
	// progress 1: th = 1 + edge_width, which exceeds every possible n, so every
	// point is past its discard point and the mesh is fully gone — no leftover
	// undissolved pixels flashing back once the tween reaches 1.0.
	float th = progress * (1.0 + edge_width);
	if (n < th - edge_width) {
		discard;
	} else if (n < th) {
		ALBEDO = edge_color.rgb;
		EMISSION = edge_color.rgb * 2.0;
	} else {
		ALBEDO = albedo_color.rgb;
	}
}
