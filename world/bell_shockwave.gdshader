shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Brightest at the silhouette of the sphere (a thin glowing ring seen from
	// either side), transparent in the middle.
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float ring = pow(rim, 5.0);
	ALBEDO = tint.rgb * 1.6;
	ALPHA = clamp(ring * fade, 0.0, 1.0);
}
