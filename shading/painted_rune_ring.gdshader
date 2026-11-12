shader_type spatial;
// A hand-painted rune circle for the ground: two wobbly ink-like rings and a
// ring of rune ticks of uneven length, slowly turning. Put it on a flat quad
// (UV 0..1) lying on the floor; the ring radius is a fraction of the quad's
// half-size. Additive and unshaded, so it just glows on whatever is below.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.95, 1.0, 1.0);
uniform float amount : hint_range(0.0, 3.0) = 1.0;   // 0 = invisible
uniform float runes = 9.0;
uniform float spin = 0.12;                            // radians per second

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + TIME * spin;
	// Hand-drawn: the radius wanders a little around the circle.
	float wob = 0.012 * sin(a * 5.0 + 1.0) + 0.009 * sin(a * 11.0 + 2.0);
	float outer = 1.0 - smoothstep(0.0, 0.03, abs(r - 0.80 - wob));
	float inner = (1.0 - smoothstep(0.0, 0.02, abs(r - 0.60 + wob))) * 0.6;
	// Rune ticks between the rings; each one a different length and thickness.
	float cell_f = a / TAU * runes;
	float id = mod(floor(cell_f), runes);
	float f = fract(cell_f);
	float h = hash11(id + 3.0);
	float half_w = 0.12 + 0.1 * h;
	float tick_w = smoothstep(0.5 - half_w - 0.04, 0.5 - half_w, f) * (1.0 - smoothstep(0.5 + half_w, 0.5 + half_w + 0.04, f));
	float r0 = 0.64;
	float r1 = 0.66 + 0.1 * hash11(id + 11.0);
	float tick_r = smoothstep(r0 - 0.02, r0, r) * (1.0 - smoothstep(r1, r1 + 0.02, r));
	float ticks = tick_w * tick_r * 0.9;
	float edge = 1.0 - smoothstep(0.88, 1.0, r);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0);
	ALBEDO = color.rgb;
	ALPHA = clamp((outer + inner + ticks) * edge * pulse * amount, 0.0, 1.0);
}
