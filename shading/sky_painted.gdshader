shader_type sky;
// Painted, anime-style daytime sky: a saturated azure-to-cyan gradient with big
// layered cumulus that are bright on the sun side and soft blue-grey underneath,
// wispy at the edges. Procedural (no textures); drifts slowly with TIME.
//
// Clouds are noise projected onto a flat layer overhead. Lighting is faked by
// sampling the same noise a little toward the sun: if the cloud is thinner
// toward the sun the pixel is on a lit edge, thicker = in shadow. That is what
// gives the soft "volume" without any raymarching.

group_uniforms gradient;
uniform vec3 top_color : source_color = vec3(0.10, 0.42, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.90, 1.0);
uniform float gradient_power : hint_range(0.2, 4.0) = 1.4;   // higher = more of the sky stays deep blue

group_uniforms clouds;
uniform float coverage : hint_range(0.0, 1.0) = 0.55;        // how much of the sky is cloud
uniform float softness : hint_range(0.02, 0.6) = 0.28;       // edge softness (wispy vs hard)
uniform float cloud_scale : hint_range(0.2, 6.0) = 1.3;      // bigger = smaller clouds
uniform float wind_speed : hint_range(0.0, 0.2) = 0.012;
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.60, 0.72, 0.92);
uniform float light_reach : hint_range(0.0, 0.5) = 0.12;     // how far toward the sun the shading samples
uniform float shading_contrast : hint_range(0.5, 8.0) = 3.5;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 4 octaves; a coarse warp first makes the shapes billow instead of look like plain noise.
float density(vec2 p) {
	p += vec2(vnoise(p * 0.7 + 3.1), vnoise(p * 0.7 + 8.7)) * 0.8;
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + 11.3;
		a *= 0.5;
	}
	return v;   // ~0..0.94
}

void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, 0.0, 1.0);

	// Gradient: deep at the zenith, pale cyan toward the horizon.
	vec3 col = mix(horizon_color, top_color, pow(up, gradient_power));

	// Project onto a flat layer: dir.xz / height. The +0.12 stops it exploding at the horizon.
	vec2 uv = dir.xz / (max(dir.y, 0.0) + 0.12) * cloud_scale + vec2(TIME * wind_speed, TIME * wind_speed * 0.4);
	float d = density(uv);
	float lo = 1.0 - coverage * 0.75 - 0.15;
	float cover = smoothstep(lo, lo + softness, d);

	// Fake lighting: compare with the density a step toward the sun.
	vec2 sun_xz = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001));
	float d_sun = density(uv + sun_xz * light_reach);
	float lit = clamp(0.5 + (d - d_sun) * shading_contrast, 0.0, 1.0);   // thinner toward the sun -> lit
	// thick cores are darker underneath, thin edges glow
	float core = smoothstep(lo + softness, lo + softness + 0.25, d);
	vec3 cloud_col = mix(cloud_shadow, cloud_light, clamp(lit * (1.0 - core * 0.45) + (1.0 - core) * 0.35, 0.0, 1.0));

	// Clouds fade into the haze right at the horizon, and there are none below it
	// (sky() can't `return` early, so this is a mask instead of a branch).
	float horizon_fade = smoothstep(0.0, 0.22, dir.y);
	vec3 sky_col = mix(col, cloud_col, cover * horizon_fade);

	// Below the horizon: just continue the horizon colour, slightly darker.
	float below = clamp(-dir.y * 3.0, 0.0, 1.0);
	COLOR = mix(sky_col, horizon_color * 0.8, below);
}
