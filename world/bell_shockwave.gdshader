shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float ring_width : hint_range(0.01, 0.5) = 0.07;   // of the radius

void fragment() {
	// A flat disc whose UV centre is the bell: bright only in a thin band at
	// the disc's edge, so it reads as a ring running outward along the ground
	// plane, with a soft trailing glow behind the leading edge.
	float r = length(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(1.0 - ring_width, 1.0 - ring_width * 0.15, r) * (1.0 - smoothstep(0.985, 1.0, r));
	float trail = smoothstep(1.0 - ring_width * 4.0, 1.0, r) * 0.18 * (1.0 - smoothstep(0.985, 1.0, r));
	ALBEDO = tint.rgb * 1.8;
	ALPHA = clamp((edge + trail) * fade, 0.0, 1.0);
}
