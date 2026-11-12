shader_type spatial;
// Cartoony cel-shaded crystal: three hard tone bands (shadow / base / light)
// from one fixed light direction, a crisp white glint that slides across the
// facets as it turns, and a hard-edged bright rim. No gradients, no noise —
// flat colour with sharp edges. Unshaded: it carries its own light. Pair it
// with shading/cel_outline.gdshader as `next_pass` for the black ink outline.
render_mode unshaded, cull_back, fog_disabled;

uniform vec4 tint : source_color = vec4(0.0, 0.54, 1.0, 1.0);   // the crystal's base colour
uniform float glow : hint_range(0.0, 4.0) = 1.0;                // 1 = normal; above 1 flashes toward white
uniform vec3 cel_light = vec3(-0.45, 0.8, 0.4);                 // world direction of the light
uniform float light_edge = 0.25;                                // dot() above this = light band
uniform float shadow_edge = -0.3;                               // dot() below this = shadow band
uniform float glint_edge = 0.93;                                // higher = smaller glint
uniform float rim_edge = 0.68;                                  // higher = thinner rim

varying vec3 v_world_normal;

void vertex() {
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	vec3 l = normalize(cel_light);
	float lit = dot(n, l);

	vec3 shadow_col = tint.rgb * vec3(0.38, 0.42, 0.8);   // shadows lean toward blue-violet, like a drawn cel
	vec3 light_col = mix(tint.rgb, vec3(1.0), 0.4);
	vec3 col = tint.rgb;
	col = mix(col, shadow_col, step(lit, shadow_edge));
	col = mix(col, light_col, step(light_edge, lit));

	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float glint = step(glint_edge, dot(n, normalize(l + view_world)));
	col = mix(col, vec3(1.0), glint);

	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	col = mix(col, light_col, step(rim_edge, 1.0 - facing) * 0.85);

	col *= 0.7 + 0.3 * min(glow, 1.0);                        // a locked crystal reads duller
	col = mix(col, vec3(1.0), clamp(glow - 1.0, 0.0, 1.0) * 0.6);   // activation flash
	ALBEDO = col;
}
