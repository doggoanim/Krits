shader_type canvas_item;
// Earthy fill for the rock-armor shield bar: keeps the bar art's shape
// (alpha, edge cut as it drains) but paints it with a tiled dirt texture,
// tinted brown, with a little of the art's own shading on top.
// The bar is drawn UV-mapped (UV x spans 0..fraction of the full bar), so the
// dirt stays put as the bar drains instead of sliding.

uniform sampler2D dirt : source_color, filter_nearest, repeat_enable;
uniform vec2 tiling = vec2(4.2, 0.82);   // bar size / texture size, so texels stay square
uniform vec4 tint : source_color = vec4(0.62, 0.4, 0.17, 1.0);

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec3 soil = texture(dirt, UV * tiling).rgb;
	float shade = 0.75 + 0.5 * dot(art.rgb, vec3(0.3333));
	COLOR = vec4(clamp(soil * tint.rgb * 1.6 * shade, 0.0, 1.0), art.a);
}
