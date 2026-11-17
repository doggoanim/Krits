shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Turns OutlineSystem's isolated character-silhouette render into a ring right outside
// it: the outer edge of the WHOLE character, not a seam line between each of its body-part
// meshes. `silhouette` contains nothing but the outlined characters against full
// transparency, so only its alpha matters: a circular dilation of the alpha is
// approximated by sampling a small ring of points out to `width_px`, and wherever that
// is higher than the pixel's own alpha, that pixel is the outline (the character's real
// pixels are left to the main camera).
//
// This is a fullscreen quad in the 3D pass (not a canvas overlay) so it can read the real
// scene depth: a ring pixel is dropped wherever something in the scene is in front of the
// character it belongs to. So an NPC half behind a wall keeps the outline on the half that
// is visible and loses it exactly where the wall covers it, like any other part of it.
// The character a ring pixel belongs to is the nearest (on screen, weighted by distance)
// of the ones OutlineSystem lists in char_pos / char_radius.

const int MAX_CHARS = 16;

uniform sampler2D silhouette : hint_default_transparent, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float width_px : hint_range(0.5, 16.0) = 3.0;
uniform int char_count = 0;
uniform vec4 char_pos[MAX_CHARS];      // xyz = world centre; w > 0.5 = never hidden (the player)
uniform float char_radius[MAX_CHARS];  // roughly half the character's size, in metres

float view_depth_at(vec2 uv, mat4 inv_projection) {
	float d = texture(scene_depth, uv).x;
	vec4 v = inv_projection * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -(v.z / v.w);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(silhouette, 0));
	float center_alpha = texture(silhouette, SCREEN_UV).a;
	float dilated = center_alpha;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * (TAU / 8.0);
		vec2 dir = vec2(cos(angle), sin(angle));
		dilated = max(dilated, texture(silhouette, SCREEN_UV + dir * width_px * texel).a);
		dilated = max(dilated, texture(silhouette, SCREEN_UV + dir * width_px * 0.5 * texel).a);
	}
	float ring = clamp(dilated - center_alpha, 0.0, 1.0);
	if (ring <= 0.0) {
		discard;
	}

	// Which character is this ring pixel around?
	float best = 1e9;
	float best_depth = 0.0;
	float best_radius = 0.0;
	bool always = false;
	for (int i = 0; i < MAX_CHARS; i++) {
		if (i >= char_count) {
			break;
		}
		vec4 v = VIEW_MATRIX * vec4(char_pos[i].xyz, 1.0);
		float depth = -v.z;
		if (depth < 0.05) {
			continue;
		}
		vec4 clip = PROJECTION_MATRIX * v;
		vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
		float score = length(uv - SCREEN_UV) * depth / max(char_radius[i], 0.2);
		if (score < best) {
			best = score;
			best_depth = depth;
			best_radius = char_radius[i];
			always = char_pos[i].w > 0.5;
		}
	}

	float visible = 1.0;
	if (!always && best < 1e8) {
		float scene = view_depth_at(SCREEN_UV, INV_PROJECTION_MATRIX);
		if (scene < best_depth - best_radius * 0.5 - 0.15) {
			visible = 0.0;   // something solid is in front of the character here
		}
	}
	ALBEDO = outline_color.rgb;
	ALPHA = ring * outline_color.a * visible;
}
