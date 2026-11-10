shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// The underwater arena's barrier: a wall of air. A faint blue membrane with
// bubbles drifting up it, brighter near the seabed. World-space, so the
// separate wall segments read as one continuous bubble curtain.

global uniform float time_offset;   // pausable shader clock — see ShaderClock

uniform vec4 tint : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float wall_height = 90.0;   // set by Arena (shared with arena_wall.gdshader)
uniform float below_ground = 14.0;
uniform float fade_height = 14.0;   // metres over which the curtain fades out going up
uniform float bubble_scale = 1.6;   // bubbles per metre
uniform float rise_speed = 0.6;
uniform float base_alpha = 0.22;

varying vec3 wpos;
varying float h;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = VERTEX.y + wall_height * 0.5 - below_ground;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float t = TIME - time_offset;
	float fade = (1.0 - smoothstep(0.0, fade_height, h)) * (1.0 - smoothstep(0.0, below_ground, -h));
	// Cells along the wall (horizontal position) x height; each cell may hold one bubble ring.
	vec2 uv = vec2((wpos.x + wpos.z) * bubble_scale, h * bubble_scale - t * rise_speed);
	vec2 cell = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float rnd = hash21(cell);
	vec2 off = (vec2(hash21(cell + 7.1), hash21(cell + 3.7)) - 0.5) * 0.4;
	float r = 0.12 + 0.18 * rnd;
	float d = length(f - off);
	float ring = smoothstep(0.035, 0.0, abs(d - r)) * step(0.45, rnd);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float base = base_alpha * (0.5 + 0.5 * fresnel);
	float a = (base + ring * 0.7) * fade;
	ALBEDO = mix(tint.rgb, vec3(1.0), ring);
	ALPHA = clamp(a, 0.0, 0.85);
}
