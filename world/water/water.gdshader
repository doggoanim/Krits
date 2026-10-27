shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon, blend_mix;
// Simple stylized water: a toon-stepped shallow/deep color blend plus a
// couple of layered sine waves for gentle animated motion, and a fresnel
// rim so it brightens at grazing angles like a real reflective surface.
// No shoreline foam or real depth-based shading yet — that would need
// reading the depth buffer to see what's underneath each pixel; flag it
// if you want that added as a second pass.

uniform sampler2D albedo_texture : source_color;   // optional — leave empty for the flat toon-color look
uniform vec2 uv_scroll_speed = vec2(0.05, 0.03);   // UV units/sec, only matters if a texture is set
uniform vec4 shallow_color : source_color = vec4(0.4, 0.8, 0.85, 0.65);
uniform vec4 deep_color : source_color = vec4(0.05, 0.25, 0.45, 0.9);
uniform float wave_height = 0.08;
uniform float wave_scale = 1.3;     // world units per wave
uniform float wave_speed = 0.6;
uniform float fresnel_power = 3.0;
uniform float color_bands = 3.0;    // flat color steps instead of a smooth gradient, for the toon look

uniform float sparkle_strength : hint_range(0.0, 2.0) = 0.0;   // 0 disables sparkle entirely
uniform float sparkle_density = 40.0;    // sparkle cells per world unit — higher = finer, more numerous glints
uniform float sparkle_speed = 2.5;       // how often each cell's on/off state re-rolls
uniform vec4 sparkle_color : source_color = vec4(1.0, 1.0, 0.95, 1.0);

varying float wave_offset;
varying vec2 world_xz;   // only needed by the sparkle pass below, but cheap enough to always compute

// Cheap per-cell pseudo-random value, no texture lookup needed — same
// "hash a 2D point to 0..1" trick used all over shader sparkle/glitter
// effects. Not meant to be a good general-purpose noise, just a fast way to
// give each sparkle cell its own stable-but-changing on/off roll.
float sparkle_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world_pos.xz;
	float w1 = sin(world_pos.x * wave_scale + TIME * wave_speed);
	float w2 = sin((world_pos.x + world_pos.z) * wave_scale * 0.6 - TIME * wave_speed * 1.3);
	wave_offset = (w1 + w2) * 0.5;
	VERTEX.y += wave_offset * wave_height;
}

void fragment() {
	// Driven by the wave height itself rather than real depth, just to get
	// some visible variation across the surface without a depth-buffer pass.
	float t = smoothstep(-1.0, 1.0, wave_offset);
	t = floor(t * color_bands) / max(color_bands - 1.0, 1.0);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, t);
	float alpha = mix(shallow_color.a, deep_color.a, t);

	// Texture is optional: an unset sampler2D defaults to solid white, so
	// this multiply is a no-op (leaves the flat toon-color look untouched)
	// until you actually assign one.
	vec2 scrolled_uv = UV + TIME * uv_scroll_speed;
	vec4 tex = texture(albedo_texture, scrolled_uv);
	color *= tex.rgb;
	alpha *= tex.a;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	ALBEDO = color;
	ALPHA = clamp(alpha + fresnel * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.05;
	METALLIC = 0.0;

	if (sparkle_strength > 0.0) {
		// Each wave crest nudges the cell grid it samples, so a sparkle
		// cell's on/off roll re-happens as the water moves rather than
		// sitting in a perfectly static world-space lattice — reads as
		// glints riding the surface motion instead of a fixed glitter
		// pattern painted on top of it.
		vec2 cell = floor((world_xz + wave_offset * 0.1) * sparkle_density);
		float roll = floor(TIME * sparkle_speed);
		float n = sparkle_hash(cell + roll);
		// Narrow threshold: only a sparse handful of cells are "lit" on any
		// given roll, which is what reads as scattered glints rather than a
		// uniform shimmer over the whole surface.
		float twinkle = step(0.992, n);
		// Glints only belong near the water's own bright/grazing highlight,
		// same view-facing term fresnel already uses above — keeps them
		// looking like light catching the surface rather than floating
		// dots unrelated to the lighting.
		float facing = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		EMISSION += sparkle_color.rgb * twinkle * facing * sparkle_strength;
	}
}
