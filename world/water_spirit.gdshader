shader_type spatial;
render_mode unshaded, cull_back, blend_mix;
// A water spirit's body: a droplet with a pointed top, flat toon colour bands
// from deep blue (bottom) to pale aqua (top), and a hard white rim light, like
// the water in world/water/water.gdshader but wrapped around a little creature.

global uniform float time_offset;   // pausable shader clock — see ShaderClock

uniform vec4 deep_color : source_color = vec4(0.16, 0.5, 0.92, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.62, 0.93, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float bands = 3.0;           // flat colour steps instead of a smooth gradient
uniform float rim_power = 2.4;
uniform float rim_cut = 0.5;         // higher = thinner rim
uniform float tip_pull = 0.75;       // how much the top narrows into a droplet point
uniform float tip_rise = 0.3;        // how far the point stretches upward
uniform float body_alpha = 0.92;

varying float local_y;

void vertex() {
	float t = TIME - time_offset;
	float tip = smoothstep(-0.05, 0.5, VERTEX.y);
	VERTEX.xz *= 1.0 - tip * tip_pull;
	VERTEX.y += tip * tip_rise;
	VERTEX.x += sin(t * 3.0 + VERTEX.y * 6.0) * 0.02 * tip;   // the point sways
	local_y = clamp(VERTEX.y + 0.5, 0.0, 1.0);
}

void fragment() {
	float band = floor(local_y * bands) / max(bands - 1.0, 1.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(band, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	col = mix(col, rim_color.rgb, step(rim_cut, fres));
	ALBEDO = col;
	ALPHA = body_alpha;
}
