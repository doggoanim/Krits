shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
// Far sea for EndlessWater: close in it matches the town's water, and with
// distance it fades to the horizon colour, so only what lies beyond the town's
// own water goes hazy while the town itself stays clear (no global fog needed).

uniform vec4 near_color : source_color = vec4(0.30, 0.82, 0.93, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.78, 0.88, 0.96, 1.0);
uniform float fade_start = 90.0;
uniform float fade_end = 320.0;

void fragment() {
	float d = length(VERTEX);
	float t = smoothstep(fade_start, fade_end, d);
	ALBEDO = mix(near_color.rgb, horizon_color.rgb, t);
}
