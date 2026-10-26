shader_type canvas_item;
// Chunky retro-pixel look for the whole screen: snaps every sample to a
// coarse grid before reading the already-rendered frame, so each block of
// `pixel_size` screen pixels reads back as one flat color. This is a mosaic,
// not a blur or a resolution change — nothing else in the scene has to
// render smaller or get rescaled for this to work.
//
// Driven by PixelateEffect (core/pixelate_effect.gd), which puts this on a
// full-screen ColorRect sitting above OutlineSystem's overlay but below the
// HUD, so the 3D scene and character outlines get pixelated together while
// menus/on-screen text stay crisp.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 32.0) = 4.0;   // block size, in screen pixels

void fragment() {
	vec2 block = pixel_size * SCREEN_PIXEL_SIZE;
	vec2 snapped_uv = (floor(SCREEN_UV / block) + 0.5) * block;
	COLOR = texture(screen_tex, snapped_uv);
}
