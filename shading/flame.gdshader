shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// A hand-painted, stylised flame on a card that always faces the camera (turning around
// its own up axis only, so it stays upright). Everything is drawn in the fragment shader:
// a teardrop whose edge wobbles and licks upward with scrolling noise, filled with hard
// colour bands (red rim, orange body, yellow core, cream heart) whose borders are
// roughened by vertical "brush streaks", so it reads as painted rather than gradient-lit.
// The tip breaks up into dry-brush flecks. `seed` makes each card flicker differently.

const float STEP_SECONDS = 0.083333;   // 2 frames at 24 fps: keep in sync with core/choppy.gd

uniform vec4 rim_color : source_color = vec4(0.78, 0.12, 0.06, 1.0);
uniform vec4 body_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.78, 0.2, 1.0);
uniform vec4 heart_color : source_color = vec4(1.0, 0.96, 0.7, 1.0);
uniform float seed = 0.0;
uniform float speed = 1.0;        // how fast the flame licks upward
uniform float wobble = 0.16;      // how far the whole flame sways
uniform float fatness = 1.0;      // 1 = normal, <1 slimmer, >1 plumper

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	// Upright billboard: face the camera around the card's own Y axis.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		MODEL_MATRIX[1],
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	float t = 1.0 - UV.y;                       // 0 at the base, 1 at the tip
	float time = floor(TIME / STEP_SECONDS) * STEP_SECONDS * speed + seed * 7.0;   // held in poses, like the hand-made animations
	float x = (UV.x - 0.5) * 2.0;
	// the flame sways more the higher it is
	x += sin(t * 5.0 - time * 3.1) * wobble * t + (vnoise(vec2(t * 2.0, time * 0.7)) - 0.5) * wobble * t * 2.0;
	// teardrop: round base, long licking tip
	float profile = pow(1.0 - t, 0.85) * (0.42 + 0.58 * sqrt(clamp(t / 0.22, 0.0, 1.0))) * fatness;
	// ragged edge, noise scrolling upward
	float edge = vnoise(vec2(x * 3.2, t * 3.4 - time * 1.9));
	float s = profile - abs(x) * 0.95 + (edge - 0.5) * 0.42 * (0.25 + t);
	// brush streaks: tall thin noise that roughens where the colour bands change
	float streak = vnoise(vec2(x * 9.0 + seed * 3.0, t * 1.4 - time * 1.1)) - 0.5;
	float band = s + streak * 0.16;
	// dry-brush tip: flecks instead of a clean point
	float fleck = hash21(floor(vec2(UV.x * 18.0, UV.y * 26.0 + floor(time * 6.0))));
	float tip_break = smoothstep(0.55, 0.95, t);
	if (s < 0.0 || (tip_break > 0.0 && fleck < tip_break * 0.55 && s < 0.12)) {
		discard;
	}
	vec3 c = rim_color.rgb;
	c = band > 0.13 ? body_color.rgb : c;
	c = band > 0.30 ? core_color.rgb : c;
	c = band > 0.46 ? heart_color.rgb : c;
	ALBEDO = c;
	ALPHA = 1.0;
}
