shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// Toon foam ring drawn on the water's surface around the player: the same
// hard-edged white as the shoreline foam in world/water/water.gdshader, with a
// wobbling edge and a thin outer ring that breathes in and out. Drawn flat on a
// quad (see PlayerEffects.update_water_foam()); the opaque-depth foam in the water
// shader can't give a character this, because it's only a hair wide on a
// steep body and the water shader's band is tuned for shores.

global uniform float time_offset;   // pausable shader clock — see ShaderClock

uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float opacity = 1.0;        // faded by the effects script with submersion
uniform float inner = 0.34;         // where the solid band starts (fraction of the quad half-size)
uniform float band = 0.2;           // solid band thickness
uniform float ring_gap = 0.1;       // gap between the band and the thin outer ring
uniform float ring_width = 0.05;

void fragment() {
	float t = TIME - time_offset;
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float wob = 0.025 * sin(ang * 7.0 + t * 2.0) + 0.018 * sin(ang * 13.0 - t * 3.0);
	float breathe = 0.02 * sin(t * 2.2);
	float solid = step(inner + wob, r) * step(r, inner + band + wob + breathe);
	float outer_r = inner + band + ring_gap + wob + breathe * 2.0;
	float thin = step(outer_r, r) * step(r, outer_r + ring_width);
	float a = max(solid, thin * 0.85) * opacity;
	ALBEDO = foam_color.rgb;
	ALPHA = a;
}
