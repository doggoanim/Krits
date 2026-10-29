shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon, blend_mix;
// Pausable clock (see core/shader_clock.gd): TIME keeps running while the
// game is paused, so ShaderClock publishes how much of it was spent paused
// and we subtract that — animation freezes with the pause menu. (Unset, e.g.
// in the editor's own viewport, it's 0 and this is plain TIME.)
global uniform float time_offset;
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

// Cheap per-cell pseudo-random value, no texture lookup needed. This is the
// well-mixed "hash without sine" variant: the older fract(p * k) product hash
// leaves visible diagonal/straight-line patterns in the lit cells.
float sparkle_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// One layer of glints: a randomly rotated cell grid (so no axis-aligned
// lattice), where every cell has its own timing (they don't all re-roll on the
// same beat), its own brightness and fades in/out instead of popping.
float sparkle_layer(vec2 p, float density, float angle, float seed, float t) {
	float c = cos(angle);
	float s = sin(angle);
	vec2 q = mat2(vec2(c, s), vec2(-s, c)) * p * density;
	vec2 cell = floor(q) + seed;
	float phase = sparkle_hash(cell * 1.31);
	float clock = t * sparkle_speed + phase * 11.0;
	float roll = floor(clock);
	float n = sparkle_hash(cell + roll * 17.7);
	float lit = step(0.992, n);
	float pulse = sin(fract(clock) * 3.14159);   // fade in and out across the roll
	float bright = 0.5 + 0.5 * sparkle_hash(cell + roll * 3.1);
	return lit * pulse * bright;
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world_pos.xz;
	float w1 = sin(world_pos.x * wave_scale + (TIME - time_offset) * wave_speed);
	float w2 = sin((world_pos.x + world_pos.z) * wave_scale * 0.6 - (TIME - time_offset) * wave_speed * 1.3);
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
	vec2 scrolled_uv = UV + (TIME - time_offset) * uv_scroll_speed;
	vec4 tex = texture(albedo_texture, scrolled_uv);
	color *= tex.rgb;
	alpha *= tex.a;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	ALBEDO = color;
	ALPHA = clamp(alpha + fresnel * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.05;
	METALLIC = 0.0;

	if (sparkle_strength > 0.0) {
		// Two glint layers at different densities and angles, each nudged by the
		// wave height so they ride the surface motion rather than sitting in a
		// fixed lattice.
		vec2 p = world_xz + wave_offset * 0.1;
		float t = TIME - time_offset;
		float twinkle = sparkle_layer(p, sparkle_density, 0.61, 0.0, t)
				+ sparkle_layer(p, sparkle_density * 0.57, 2.17, 37.0, t);
		// Glints only belong near the water's own bright/grazing highlight,
		// same view-facing term fresnel already uses above — keeps them
		// looking like light catching the surface rather than floating
		// dots unrelated to the lighting.
		float facing = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		EMISSION += sparkle_color.rgb * twinkle * facing * sparkle_strength;
	}
}
