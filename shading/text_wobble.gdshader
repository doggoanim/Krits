shader_type canvas_item;
// A slight hand-drawn wobble for UI text: every glyph corner is nudged by
// smooth sines of its position, so letters sit a touch crooked and uneven
// without being hard to read. Applied by core/text_wobble.gd.

uniform float amplitude = 1.4;      // pixels of displacement
uniform float frequency = 0.045;    // how fast the wobble varies across the screen (per pixel)
uniform float boil_fps = 0.0;       // > 0 re-rolls the wobble that many times a second (stop-motion boil); 0 = still

void vertex() {
	float seed = boil_fps > 0.0 ? floor(TIME * boil_fps) * 3.7 : 0.0;
	vec2 p = VERTEX * frequency;
	VERTEX.x += sin(p.y * 1.7 + p.x * 0.9 + seed) * amplitude;
	VERTEX.y += sin(p.x * 1.3 - p.y * 1.1 + seed * 1.3) * amplitude;
}
