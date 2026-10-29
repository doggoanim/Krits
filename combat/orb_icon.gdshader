shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;
// A billboarded line-art icon tinted with the orb's color. The icon art is
// dark line work on a light/transparent ground, so a plain modulate would
// stay black: instead the DARKNESS of each texel becomes the opacity and the
// tint becomes the color, which keeps every line and drops the light fills.

uniform sampler2D icon : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fade = 1.0;

void vertex() {
	// Face the camera, keep the node's position.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 t = texture(icon, UV);
	float lum = dot(t.rgb, vec3(0.3333));
	ALBEDO = tint.rgb;
	ALPHA = t.a * smoothstep(0.85, 0.25, lum) * fade;
}
