shader_type canvas_item;
// Turns OutlineSystem's isolated character-silhouette render into a ring
// right outside it: the outer edge of the WHOLE character, not a seam line
// between every one of its separate body-part meshes (see OutlineSystem's
// own header for why the old per-mesh inverted-hull technique couldn't do
// that). `silhouette` contains nothing but the outlined characters against
// full transparency, so this only needs to look at alpha, never color or
// depth — two touching/overlapping parts just read as one unbroken opaque
// blob here, so there's nothing for a seam artifact to come from.
//
// Technique: approximate a circular dilation of the silhouette's alpha by
// sampling a small fixed ring of points (two radii x 8 directions, plus the
// center) out to `width_px` pixels, keeping the strongest hit. Wherever that
// dilated value is higher than the pixel's own alpha, something opaque is
// within range but this exact pixel isn't part of it — that's the outline
// ring, and only that ring is drawn; the character's real pixels (already
// visible from the main 3D camera underneath this overlay) are left fully
// transparent here so this never doubles up on top of them.

uniform sampler2D silhouette : hint_default_transparent;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float width_px : hint_range(0.5, 16.0) = 3.0;

void fragment() {
	vec2 texel_size = 1.0 / vec2(textureSize(silhouette, 0));
	float center_alpha = texture(silhouette, UV).a;

	float dilated = center_alpha;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * (TAU / 8.0);
		vec2 dir = vec2(cos(angle), sin(angle));
		dilated = max(dilated, texture(silhouette, UV + dir * width_px * texel_size).a);
		dilated = max(dilated, texture(silhouette, UV + dir * width_px * 0.5 * texel_size).a);
	}

	float ring = clamp(dilated - center_alpha, 0.0, 1.0);
	COLOR = vec4(outline_color.rgb, ring * outline_color.a);
}
