shader_type spatial;
render_mode cull_disabled;
// Cloth hanging in the wind: laundry, bunting pennants, stall awnings. The free
// end flutters most, the end it hangs from stays put. world/cloth_sway.gd pushes
// `gust` every frame from the shared gust field (world/wind_gusts.gd), so cloth
// whips harder exactly when the grass and signs do.
//
// Pausable clock: see shader_clock.gd (TIME - time_offset freezes with the pause menu).
global uniform float time_offset;
#include "res://shading/toon_light.gdshaderinc"

const float STEP_SECONDS = 0.083333;   // 2 frames at 24 fps: keep in sync with core/choppy.gd

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float cloth_h = 0.6;       // mesh height (m): measures how far down the hanging edge the cloth is
uniform bool tip_up = false;       // true when the free end is at +Y (a pennant's point), false when it is at -Y
uniform float sway = 0.1;          // flutter distance at the free end (m), at gust = 1
uniform float speed = 2.4;
uniform float phase = 0.0;         // per-piece offset so a line of laundry doesn't flap in unison
uniform float gust = 1.0;

void vertex() {
	float free_end = clamp(tip_up ? 0.5 + VERTEX.y / cloth_h : 0.5 - VERTEX.y / cloth_h, 0.0, 1.0);
	float held = floor((TIME - time_offset) / STEP_SECONDS) * STEP_SECONDS;   // poses are held, like the hand-made animations
	float t = held * speed + phase + MODEL_MATRIX[3].x * 0.6;
	VERTEX.z += sin(t + VERTEX.x * 3.0) * sway * gust * free_end;
	VERTEX.x += sin(t * 0.7 + 1.3) * sway * 0.35 * gust * free_end;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float band;
	DIFFUSE_LIGHT += toon_diffuse(ALBEDO, NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, band);
}
