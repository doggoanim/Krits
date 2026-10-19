shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_back;
// Used by PlayerXray for the "see the player through walls" silhouette:
// a screen-space halftone dot pattern instead of a flat transparent fill,
// classic comic/print "x-ray" look. Screen-space (not UV-mapped to the
// mesh) so the dot grid stays a fixed size and orientation regardless of
// camera distance or the character's pose.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dot_scale = 90.0;   // dots across the screen's shorter axis
uniform float dot_size = 0.32;    // 0..0.5, how much of each cell the dot fills

void fragment() {
	vec2 aspect_fix = vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	vec2 uv = SCREEN_UV * aspect_fix * dot_scale;
	vec2 cell_center = fract(uv) - 0.5;
	float dist = length(cell_center);
	float dot_mask = 1.0 - smoothstep(dot_size - 0.06, dot_size + 0.06, dist);
	ALBEDO = tint.rgb;
	ALPHA = dot_mask * tint.a;
}
