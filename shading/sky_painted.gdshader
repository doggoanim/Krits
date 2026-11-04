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
uniform vec3 top_color : source_color = vec3(0.04, 0.32, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.55, 0.88, 1.0);
uniform float gradient_power : hint_range(0.2, 4.0) = 0.8;   // higher = more of the sky stays deep blue

group_uniforms clouds;
uniform float coverage : hint_range(0.0, 1.0) = 0.55;        // how much of the sky is cloud
uniform float softness : hint_range(0.02, 0.6) = 0.2;       // edge softness (wispy vs hard)
uniform float cloud_scale : hint_range(0.2, 6.0) = 2.2;      // bigger = smaller clouds
uniform float wind_speed : hint_range(0.0, 0.2) = 0.012;
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.50, 0.64, 0.90);
uniform float light_reach : hint_range(0.0, 0.5) = 0.12;     // how far toward the sun the shading samples
uniform float shading_contrast : hint_range(0.5, 8.0) = 3.5;

// Cloud shapes come from a tileable noise TEXTURE (a NoiseTexture2D, set on the
// material) rather than hash-based value noise computed here: hashed noise
// showed up as blocky, straight-edged patches on some GPUs, whereas sampling a
// filtered texture is always smooth.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float noise_tile : hint_range(0.01, 1.0) = 0.3;   // how many noise-texture repeats per unit of sky plane

float vnoise(vec2 p) {
	return texture(noise_tex, p * noise_tile).r;
}

// Three layers of the noise texture at growing frequency, after a gentle warp
// so shapes billow instead of looking like plain noise.
float density(vec2 p) {
	p += vec2(vnoise(p * 0.6 + 0.31), vnoise(p * 0.6 + 0.77) ) * 0.9 - 0.45;
	float v = 0.55 * vnoise(p);
	v += 0.30 * vnoise(p * 2.1 + 0.19);
	v += 0.15 * vnoise(p * 4.3 + 0.53);
	return v;   // ~0..1, centred near 0.5
}

void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, 0.0, 1.0);

	// Gradient: deep at the zenith, pale cyan toward the horizon.
	vec3 col = mix(horizon_color, top_color, pow(up, gradient_power));

	// Project onto a flat layer: dir.xz / height. The +0.4 limits how much clouds stretch out at the horizon.
	vec2 uv = dir.xz / (max(dir.y, 0.0) + 0.4) * cloud_scale + vec2(TIME * wind_speed, TIME * wind_speed * 0.4);
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
