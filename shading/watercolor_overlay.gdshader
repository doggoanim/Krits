shader_type canvas_item;
// Watercolor look for the whole screen, as a post-process over the already
// rendered frame (same bolt-on pattern as pixelate_overlay.gdshader — see
// WatercolorEffect in core/watercolor_effect.gd, which owns this).
//
// What makes it read as watercolor, in the order it's applied:
//   1. WOBBLE   — the image is nudged by low-frequency noise, so edges wander
//                 like a hand-painted outline instead of a ruler-straight one.
//   2. WASH     — a soft blur plus a gentle posterize flattens detail into
//                 broad, even pigment washes.
//   3. GRANULATION — fine noise lightens/darkens the pigment unevenly, like
//                 paint settling into paper grain.
//   4. EDGE POOLING — pigment gathers at the borders of a shape, so edges get a
//                 darker, slightly tinted rim (found with a Sobel filter).
//   5. PAPER    — a fibrous paper texture multiplies over everything, and the
//                 brightest highlights fade to bare paper (watercolor has no
//                 white paint; white is the paper showing through).
// Everything is procedural (no texture assets) and sits in screen space, like
// paper under the painting. `strength` blends the whole effect in and out.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float strength : hint_range(0.0, 1.0) = 1.0;

group_uniforms wobble;
uniform float wobble_pixels : hint_range(0.0, 12.0) = 3.0;     // how far edges wander, in screen pixels
uniform float wobble_scale : hint_range(8.0, 200.0) = 60.0;    // size of the wobble features, in pixels
uniform float boil_fps : hint_range(0.0, 24.0) = 5.0;          // hand-drawn "boil": re-rolls the wobble this often (0 = static)
uniform float boil_amount : hint_range(0.0, 1.0) = 0.12;       // how much the wobble changes between re-rolls

group_uniforms wash;
uniform float blur_radius : hint_range(0.0, 8.0) = 2.0;        // wash softness, in screen pixels
uniform float color_bands : hint_range(3.0, 24.0) = 10.0;      // number of soft color steps
uniform float flatten : hint_range(0.0, 1.0) = 0.55;           // how strongly colors snap to the steps
uniform float saturation : hint_range(0.0, 1.5) = 1.05;

group_uniforms pigment;
uniform float granulation : hint_range(0.0, 1.0) = 0.22;       // uneven pigment settling
uniform float granulation_scale : hint_range(1.0, 20.0) = 4.0; // grain size, in pixels
uniform float edge_strength : hint_range(0.0, 1.0) = 0.55;     // darkened rim at edges
uniform float edge_width : hint_range(0.5, 4.0) = 1.4;         // edge detection reach, in pixels
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.06;    // how contrasty an edge must be to pool pigment
uniform vec3 edge_tint : source_color = vec3(0.50, 0.46, 0.58);

group_uniforms paper;
uniform vec3 paper_color : source_color = vec3(0.97, 0.95, 0.90);
uniform float paper_strength : hint_range(0.0, 1.0) = 0.45;    // visible paper texture
uniform float paper_scale : hint_range(1.0, 40.0) = 6.0;       // paper grain size, in pixels
uniform float highlight_lift : hint_range(0.0, 1.0) = 0.55;    // how much bright areas fade to bare paper
uniform float highlight_start : hint_range(0.3, 1.0) = 0.72;   // brightness where that fade begins

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;   // roughly 0..0.94
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Soft posterize: snaps toward the nearest step but blends across each step's
// edge, so bands look like overlapping washes rather than hard contour lines.
vec3 soft_bands(vec3 c, float bands) {
	vec3 x = c * bands;
	vec3 base = floor(x);
	vec3 t = smoothstep(vec3(0.3), vec3(0.7), fract(x));
	return (base + t) / bands;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 frag = FRAGCOORD.xy;
	vec3 original = texture(screen_tex, SCREEN_UV).rgb;

	// --- 1. wobble ---------------------------------------------------------
	float step_a = floor(TIME * boil_fps);
	vec2 boil = vec2(step_a * 13.7, step_a * 7.3) * boil_amount;
	vec2 p = frag / wobble_scale;
	vec2 offset = vec2(fbm(p + boil), fbm(p + vec2(31.7, 11.3) + boil)) - 0.47;
	vec2 uv = SCREEN_UV + offset * wobble_pixels * 2.0 * px;

	// --- 2. wash: soft blur + gentle posterize ---------------------------------
	vec3 sum = texture(screen_tex, uv).rgb * 2.0;
	float weight = 2.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 dir = vec2(cos(a), sin(a));
		sum += texture(screen_tex, uv + dir * blur_radius * px).rgb;
		sum += texture(screen_tex, uv + dir * blur_radius * 0.5 * px).rgb;
		weight += 2.0;
	}
	vec3 c = sum / weight;
	c = mix(c, soft_bands(c, color_bands), flatten);
	float l = luma(c);
	c = mix(vec3(l), c, saturation);

	// --- 3. granulation ------------------------------------------------------
	float grain = fbm(frag / granulation_scale);
	c *= 1.0 + (grain - 0.47) * granulation * 1.6;

	// --- 4. edge pooling (Sobel on the wobbled image) -------------------------
	vec2 e = edge_width * px;
	float tl = luma(texture(screen_tex, uv + vec2(-e.x, -e.y)).rgb);
	float tc = luma(texture(screen_tex, uv + vec2(0.0, -e.y)).rgb);
	float tr = luma(texture(screen_tex, uv + vec2(e.x, -e.y)).rgb);
	float ml = luma(texture(screen_tex, uv + vec2(-e.x, 0.0)).rgb);
	float mr = luma(texture(screen_tex, uv + vec2(e.x, 0.0)).rgb);
	float bl = luma(texture(screen_tex, uv + vec2(-e.x, e.y)).rgb);
	float bc = luma(texture(screen_tex, uv + vec2(0.0, e.y)).rgb);
	float br = luma(texture(screen_tex, uv + vec2(e.x, e.y)).rgb);
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	float edge = smoothstep(edge_threshold, edge_threshold + 0.25, length(vec2(gx, gy)));
	// uneven pooling: the rim is darker in some stretches than others
	edge *= 0.6 + 0.8 * fbm(frag / 7.0);
	c = mix(c, c * edge_tint * 1.6, clamp(edge * edge_strength, 0.0, 1.0));

	// --- 5. paper -------------------------------------------------------------
	float fibers = fbm(vec2(frag.x / (paper_scale * 0.5), frag.y / (paper_scale * 3.0)));
	float tooth = fbm(frag / paper_scale);
	float paper = fibers * 0.45 + tooth * 0.55;
	c *= mix(1.0, 0.78 + 0.5 * paper, paper_strength);
	float bright = smoothstep(highlight_start, 1.0, luma(c));
	c = mix(c, paper_color * (0.92 + 0.12 * paper), bright * highlight_lift);

	COLOR = vec4(mix(original, clamp(c, 0.0, 1.0), strength), 1.0);
}
