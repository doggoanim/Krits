shader_type spatial;
// Streaky additive "light leaking out of a gap" sheet. UV.y = 1 at the gap, 0 at
// the free end; the light is brightest at the gap and fades away from it.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float amount = 1.0;       // 0..1, fades the whole effect in/out
uniform float stripes = 7.0;      // number of rays across the sheet
uniform float shimmer_speed = 1.1;
uniform float reach = 1.6;        // >1 pulls the fade in closer to the gap

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float fade = pow(along, reach);
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.x);
	float rays = 0.55 + 0.45 * sin(UV.x * stripes * 6.2831 + TIME * shimmer_speed + along * 2.5);
	float pulse = 0.88 + 0.12 * sin(TIME * 2.1);
	ALBEDO = glow_color.rgb;
	ALPHA = clamp(fade * edge * rays * pulse * amount * glow_color.a, 0.0, 1.0);
}
