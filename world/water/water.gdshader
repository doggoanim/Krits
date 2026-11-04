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

group_uniforms toon_water;
uniform float texture_strength : hint_range(0.0, 1.0) = 1.0;   // how much albedo_texture tints the flat colours (0 = pure flat toon colour)
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float depth_color_range : hint_range(0.1, 20.0) = 3.0;   // water depth (world units) at which the colour reaches fully "deep"
uniform float foam_width : hint_range(0.0, 3.0) = 0.0;        // shoreline foam band in world units of water depth; 0 = off
uniform float foam_wobble : hint_range(0.0, 1.0) = 0.35;      // how much that band's edge undulates
uniform float line_strength : hint_range(0.0, 1.0) = 0.0;     // drifting white wave lines on the surface; 0 = off
uniform float line_scale = 1.6;                               // lines per world unit-ish (higher = finer, more numerous)
uniform float line_speed = 0.35;
group_uniforms;

uniform float sparkle_strength : hint_range(0.0, 2.0) = 2.0;   // 0 disables sparkle entirely
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
	// How deep the water is at this pixel: the gap between the surface and the
	// opaque scene behind it (read from the depth buffer).
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float thickness = -view.z + VERTEX.z;

	// Colour follows depth, not the moving waves: light shallows grading to deep
	// blue in flat steps. It is fixed in the world, so nothing scrolls across the
	// surface (the old version stepped the colour by wave height, which made
	// bands slide around as the waves moved).
	float t = smoothstep(0.0, depth_color_range, thickness);
	t = floor(t * color_bands + 0.5) / max(color_bands, 1.0);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, t);
	float alpha = mix(shallow_color.a, deep_color.a, t);

	// Texture is optional: an unset sampler2D defaults to solid white, so
	// this multiply is a no-op (leaves the flat toon-color look untouched)
	// until you actually assign one.
	vec2 scrolled_uv = UV + (TIME - time_offset) * uv_scroll_speed;
	vec4 tex = texture(albedo_texture, scrolled_uv);
	color *= mix(vec3(1.0), tex.rgb, texture_strength);
	alpha *= mix(1.0, tex.a, texture_strength);

	float clk = TIME - time_offset;

	// --- Wind Waker shoreline foam: where the water is shallow (the opaque
	// scene is close behind the surface) paint a hard-edged white band.
	// Thickness is the depth gap between the water surface and whatever is
	// behind it; the band edge wobbles with a couple of sines so the shore
	// line undulates instead of tracing the geometry exactly.
	float foam = 0.0;
	if (foam_width > 0.0) {
		float wob = sin(world_xz.x * 2.3 + clk * 0.9) * sin(world_xz.y * 1.9 - clk * 0.7)
				+ 0.6 * sin(world_xz.x * 5.1 - world_xz.y * 3.7 + clk * 1.3);
		float edge = foam_width * (1.0 + foam_wobble * wob);
		foam = step(thickness, edge);                                   // solid band at the shore
		foam = max(foam, step(abs(thickness - edge * 1.7), edge * 0.12)); // thin second ring just outside it
	}

	// --- Drifting white wave lines: thin curves from warped sines.
	float lines = 0.0;
	if (line_strength > 0.0) {
		vec2 q = world_xz * line_scale;
		// Two stacked warps (a big slow one and a smaller faster one) bend the
		// lines into curvy, uneven shapes instead of near-straight stripes.
		float a = sin(q.x + sin(q.y * 0.8 + clk * line_speed) * 3.2 + sin(q.y * 2.3 - clk * line_speed * 0.7) * 0.9 + clk * line_speed);
		float b = sin(q.y * 1.1 - sin(q.x * 0.7 - clk * line_speed * 0.8) * 2.8 - sin(q.x * 1.9 + clk * line_speed * 0.6) * 0.8 - clk * line_speed * 0.7);
		lines = max(smoothstep(0.95, 0.985, a), smoothstep(0.96, 0.99, b));
		// Break the lines into separate dashes that fade in and out, so no stripe runs on forever.
		lines *= smoothstep(-0.15, 0.5, sin(q.x * 0.55 + q.y * 0.75 + clk * line_speed * 0.4) + sin(q.y * 1.3 - q.x * 0.4 - clk * line_speed * 0.3) * 0.6);
		lines *= line_strength;
	}
	float white = max(foam, lines);
	color = mix(color, foam_color.rgb, white);
	alpha = max(alpha, white);

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
