shader_type canvas_item;
// Pausable clock (see core/shader_clock.gd): TIME keeps running while the
// game is paused, so ShaderClock publishes how much of it was spent paused
// and we subtract that — animation freezes with the pause menu. (Unset, e.g.
// in the editor's own viewport, it's 0 and this is plain TIME.)
global uniform float time_offset;
// Low-HP warning vignette: darkens and gently pulses the screen edges.
// Purely a function of `intensity` (0 = invisible, 1 = fully showing) —
// this shader has no idea what HP even is, LowHpVignette (core/low_hp_vignette.gd)
// owns deciding what that value should be each frame and just hands it over.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.5, 0.0, 0.0, 1.0);
uniform float radius : hint_range(0.0, 1.0) = 0.45;    // where the darkening starts from center
uniform float softness : hint_range(0.01, 1.0) = 0.5;  // how gradually it ramps out to the edge
uniform float pulse_speed = 2.4;
uniform float pulse_amount = 0.35;   // how much the pulse adds/subtracts from `intensity`

void fragment() {
	// UV is a 0..1 square regardless of the screen's actual aspect ratio, so
	// a plain radial distance from center would draw an ellipse stretched to
	// match a non-square viewport instead of a circle. Scaling the x offset
	// by the screen's aspect ratio (SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x
	// = width / height) corrects for that.
	vec2 centered = UV - vec2(0.5);
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(centered);

	float ring = smoothstep(radius, radius + softness, dist);
	float pulse = 1.0 + sin((TIME - time_offset) * pulse_speed) * pulse_amount;
	float alpha = ring * clamp(intensity * pulse, 0.0, 1.0);

	COLOR = vec4(vignette_color.rgb, alpha * vignette_color.a);
}
