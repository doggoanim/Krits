shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// The arena's barrier: a chalky, hand-drawn force wall. Solid chalk band at
// the ground, hatch strokes that wobble upward, fading out with height.
// Everything is computed in world space, so neighbouring wall segments (each
// its own box) line up into one continuous drawing.

global uniform float time_offset;   // pausable shader clock — see ShaderClock

uniform vec4 chalk : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wall_height = 90.0;   // mesh height, to find "metres above the ground"
uniform float band_height = 0.7;    // the solid chalk band at the base
uniform float fade_height = 9.0;    // metres over which the wall fades to nothing
uniform float hatch_scale = 1.1;    // stroke density
uniform float base_alpha = 0.5;

varying vec3 wpos;
varying float h;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = VERTEX.y + wall_height * 0.5;   // height above the segment's ground (mesh-local)
}

void fragment() {
	float t = TIME - time_offset;
	float fade = 1.0 - smoothstep(0.0, fade_height, h);
	// Diagonal hatch strokes that sway a little as they climb — jittery like
	// someone redrawing the line every few frames.
	float jitter = floor(t * 6.0);
	float sway = sin(h * 1.7 + jitter * 1.3) * 0.12;
	float coord = (wpos.x + wpos.z) * hatch_scale + h * 0.35 + sway;
	float stroke = smoothstep(0.30, 0.42, abs(fract(coord) - 0.5));
	float band = 1.0 - smoothstep(band_height * 0.8, band_height, h + sin(wpos.x * 3.0 + wpos.z * 2.0) * 0.08);
	float a = base_alpha * fade * (0.18 + 0.82 * stroke);
	a = max(a, band * 0.9);
	ALBEDO = chalk.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * chalk.a;
}
