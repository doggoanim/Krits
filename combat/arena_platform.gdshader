shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
// The arena's floor platform, drawn in the same chalky hand-drawn style as
// the barrier wall (arena_wall.gdshader): diagonal hatch strokes that jitter
// like someone redrawing them every few frames, over a faint fill, with a
// solid chalk band around the rim. World-space hatching so it lines up with
// the wall's own strokes.

global uniform float time_offset;   // pausable shader clock — see ShaderClock

uniform vec4 chalk : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float radius = 15.0;        // disc radius (local units)
uniform float rim_width = 0.7;      // the solid chalk band around the edge
uniform float hatch_scale = 1.1;    // stroke density — matches the wall's
uniform float base_alpha = 0.5;
uniform float side_depth = 2.0;     // how far down the side edge fades out

varying vec3 wpos;
varying vec3 lpos;
varying float facing_up;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
	facing_up = step(0.5, NORMAL.y);
}

void fragment() {
	float t = TIME - time_offset;
	float jitter = floor(t * 6.0);
	float sway = sin((wpos.x - wpos.z) * 1.3 + jitter * 1.3) * 0.12;
	float coord = (wpos.x + wpos.z) * hatch_scale + sway;
	float stroke = smoothstep(0.30, 0.42, abs(fract(coord) - 0.5));
	float r = length(lpos.xz);
	float rim = smoothstep(radius - rim_width, radius - rim_width * 0.8, r + sin(atan(lpos.z, lpos.x) * 9.0) * 0.08);
	// Top face: hatch over a faint fill. Sides: strokes only, fading downward.
	float top_a = base_alpha * (0.18 + 0.82 * stroke);
	float depth = 1.0 - lpos.y;   // mesh is 2 tall, centred: top is local y = +1
	float side_a = base_alpha * stroke * (1.0 - smoothstep(0.0, side_depth, depth));
	float a = mix(side_a, max(top_a, rim * 0.9), facing_up);
	ALBEDO = chalk.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * chalk.a;
}
