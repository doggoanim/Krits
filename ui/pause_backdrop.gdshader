shader_type canvas_item;
// Frosted backdrop for the pause menu: blurs whatever the game last drew
// (the world is frozen behind it) and washes it slightly toward `tint`.
// Reads the screen, so it must sit on top of the scene it's blurring.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 7.0) = 1.6;     // mip level sampled — higher = blurrier
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.15);   // colour + how strongly it washes over

void fragment() {
	// 9 taps spread over the mip's pixel footprint, so the blur is smooth
	// instead of showing the mip chain's blocky texels.
	vec2 px = SCREEN_PIXEL_SIZE * exp2(blur_lod);
	vec3 sum = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			sum += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px, blur_lod).rgb;
		}
	}
	COLOR = vec4(mix(sum / 9.0, tint.rgb, tint.a), 1.0);
}
