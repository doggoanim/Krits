shader_type spatial;
// Fullscreen depth/normal edge-detection outline — darkens any pixel where
// the scene's depth or surface normal jumps sharply between it and its
// neighbors, over the WHOLE rendered frame (terrain, props, buildings,
// everything), not just meshes opted in like OutlineSystem's character
// outline. See core/world_outline.gd for how this is actually placed in the
// scene (an oversized quad parented to the camera) and set up.
//
// render_mode notes:
// - blend_mix + unshaded: this quad fully replaces whatever's behind it
//   pixel-for-pixel with either the original screen color or outline_color,
//   it isn't lit/shaded itself.
// - depth_draw_never + depth_test_disabled + cull_disabled: it's a 2D
//   post-process pass wearing a 3D mesh's clothes, not a real object — its
//   own depth and winding don't matter, only that it's visible and covers
//   the screen.
render_mode blend_mix, unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width_px : hint_range(0.5, 4.0) = 1.0;
uniform float depth_sensitivity : hint_range(0.0, 5.0) = 1.0;
uniform float normal_sensitivity : hint_range(0.0, 2.0) = 0.4;

// Undoes the raw device (NDC) depth back into a positive, camera-relative
// linear distance, using the same inverse-projection trick as Godot's own
// fog/SSAO-style screen shaders. Needed because raw depth is extremely
// non-linear — comparing it directly between neighboring pixels would make
// the outline's sensitivity wildly inconsistent between near and far
// geometry.
float linear_depth(float raw_depth, vec2 uv) {
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	return -view.z / view.w;   // Godot view space looks down -Z; negate so distance grows positive
}

// The normal/roughness buffer stores normals packed into 0..1 the same way
// a normal map does (xyz * 0.5 + 0.5). We only need direction for a dot
// product, not the roughness channel, so this is just the inverse of that
// packing — NOT the full normal_roughness_compatibility() conversion
// documented for CompositorEffect's raw buffer access, which also unpacks
// roughness. If outlines look wrong specifically where normals should
// trigger them (sharp corners, not depth steps), that fuller conversion —
// from the CompositorEffect.needs_normal_roughness docs — may be needed
// here instead:
//   float roughness = p_normal_roughness.w;
//   if (roughness > 0.5) { roughness = 1.0 - roughness; }
//   return normalize(p_normal_roughness.xyz * 2.0 - 1.0);
vec3 decode_normal(vec4 packed_normal_roughness) {
	return normalize(packed_normal_roughness.xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = (1.0 / VIEWPORT_SIZE) * outline_width_px;

	vec2 uv_l = uv - vec2(texel.x, 0.0);
	vec2 uv_r = uv + vec2(texel.x, 0.0);
	vec2 uv_u = uv + vec2(0.0, texel.y);
	vec2 uv_d = uv - vec2(0.0, texel.y);

	float d_c = linear_depth(texture(depth_tex, uv).r, uv);
	float d_l = linear_depth(texture(depth_tex, uv_l).r, uv_l);
	float d_r = linear_depth(texture(depth_tex, uv_r).r, uv_r);
	float d_u = linear_depth(texture(depth_tex, uv_u).r, uv_u);
	float d_d = linear_depth(texture(depth_tex, uv_d).r, uv_d);
	// Relative (divided by distance) rather than absolute, so a depth step
	// reads the same whether it's a meter away or a hundred meters away.
	float depth_edge = (abs(d_c - d_l) + abs(d_c - d_r) + abs(d_c - d_u) + abs(d_c - d_d)) / max(d_c, 0.001);

	vec3 n_c = decode_normal(texture(normal_roughness_tex, uv));
	vec3 n_l = decode_normal(texture(normal_roughness_tex, uv_l));
	vec3 n_r = decode_normal(texture(normal_roughness_tex, uv_r));
	vec3 n_u = decode_normal(texture(normal_roughness_tex, uv_u));
	vec3 n_d = decode_normal(texture(normal_roughness_tex, uv_d));
	float normal_edge = (1.0 - dot(n_c, n_l)) + (1.0 - dot(n_c, n_r)) + (1.0 - dot(n_c, n_u)) + (1.0 - dot(n_c, n_d));

	float edge_strength = depth_edge * depth_sensitivity + normal_edge * normal_sensitivity;
	float is_edge = step(1.0, edge_strength);

	vec3 base_color = texture(screen_tex, uv).rgb;
	ALBEDO = mix(base_color, outline_color.rgb, is_edge * outline_color.a);
	ALPHA = 1.0;
}
