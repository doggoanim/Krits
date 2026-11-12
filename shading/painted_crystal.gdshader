shader_type spatial;
// Hand-painted crystal: flat facets coloured in a few soft painted tone bands
// (shadow / mid / light / highlight of one hue) instead of real lighting, with
// uneven "brush stroke" variation stretched along the crystal and a glowing
// core. The painted light comes from one fixed world direction, so facets
// flash from tone to tone as the crystal turns. Unshaded: it IS its own light.
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.95, 1.0, 1.0);   // the crystal's hue (the "light" tone)
uniform float glow : hint_range(0.0, 4.0) = 1.0;                  // core + rim brightness; > 1 for flashes
uniform vec3 paint_light = vec3(-0.4, 0.85, 0.45);                // world direction the painted light comes from
uniform float stroke_scale = 5.0;                                 // brush strokes per object unit
uniform float stroke_amount : hint_range(0.0, 1.0) = 0.32;        // how uneven the tone bands are

varying vec3 v_obj;
varying vec3 v_world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
			mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

void vertex() {
	v_obj = VERTEX;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	float lit = dot(n, normalize(paint_light)) * 0.5 + 0.5;
	// Strokes run along the crystal (object Y), so they read as long brush pulls.
	float strokes = value_noise(v_obj * vec3(stroke_scale, stroke_scale * 0.22, stroke_scale)) - 0.5;
	lit = clamp(lit + strokes * stroke_amount, 0.0, 1.0);

	vec3 c_dark = tint.rgb * 0.32;
	vec3 c_mid = tint.rgb * 0.68;
	vec3 c_light = tint.rgb;
	vec3 c_high = mix(tint.rgb, vec3(1.0), 0.78);
	vec3 col = c_dark;
	col = mix(col, c_mid, smoothstep(0.30, 0.38, lit));
	col = mix(col, c_light, smoothstep(0.56, 0.64, lit));
	col = mix(col, c_high, smoothstep(0.84, 0.90, lit));

	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	col += tint.rgb * pow(facing, 2.0) * glow * 0.32;            // inner glow where it faces you
	col += c_high * pow(1.0 - facing, 3.0) * glow * 0.28;        // bright painted rim
	ALBEDO = clamp(col, 0.0, 1.6);
}
