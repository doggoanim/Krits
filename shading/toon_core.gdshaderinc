// Shared body of the toon shaders — see shading/toon.gdshader (single-sided) and
// shading/toon_double_sided.gdshader (cull_disabled, for walls/planes drawn from both sides).
// Project-wide cel/toon shader. The reason this exists instead of just using
// the built-in `diffuse_toon` render mode (still used by a few one-off
// materials elsewhere, e.g. the water shader): that mode only bands the
// N-dot-L term, while the shadow itself still falls off with the engine's
// normal soft PCF blur underneath it — so you get a hard-edged lit/dark
// band sitting right next to a blurry shadow edge, which reads as
// inconsistent. Overriding light() entirely lets the *shadow's* edge get
// exactly the same hard/soft treatment as the lit/dark band, because both
// come from thresholding the same `lit` value below.
//
// Alpha handling: every texture this shader is actually used with
// (character skins, world props) is fully opaque — there's no cutout art
// anywhere yet. Writing straight to ALPHA regardless still makes Godot
// classify the material as a *blended* transparent material, which has a
// cascade of side effects this project doesn't want: no depth-prepass
// contribution, no reliable shadow receiving, and — since a rigged
// character here is ~11 separate skinned MeshInstance3Ds (torso, each
// limb, hair, head, ...) all roughly the same distance from the camera —
// the transparent queue's per-*object* (not per-pixel) back-to-front sort
// between them, which flips as the camera/pose moves, which read as the
// model "clipping"/popping as parts swap draw order. ALPHA_SCISSOR_THRESHOLD
// below sidesteps all of that: it puts the material back in the opaque/
// depth-prepass pipeline (correct shadows, no sort-order flicker) while
// still supporting a hard cutout if `alpha_scissor_threshold` is ever
// raised above 0 for something that actually needs one (a leaf card, say) —
// default 0 never discards, which is correct for every opaque texture in
// the project today.
//
// Usage: duplicate shading/toon_material.tres (or make a fresh
// ShaderMaterial pointed at this shader) and assign it as a mesh surface's
// material/material override — the player model, enemies, world props,
// anything. ModelUtil.apply_cel_shading() does this automatically for any
// rigged character model (see core/model_util.gd), one dedicated material
// per mesh surface so each can be tinted independently (flash-on-hit, slime
// tint, ...) via ModelUtil.get_tint()/set_tint(). It also carries over
// vertex-color-as-albedo from the source material if that's how it was
// authored (use_vertex_color) rather than assuming every model's actual
// color lives in albedo_color/albedo_texture.

uniform sampler2D albedo_texture : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_vertex_color = false;   // multiply in the mesh's own vertex colors, matching BaseMaterial3D.vertex_color_use_as_albedo
uniform float texture_flatten : hint_range(0.0, 1.0) = 0.0;   // evens out brightness baked into the texture (painted-in highlights/shading) so the toon lighting does the shading instead; 0 = off
uniform vec2 uv_scale = vec2(1.0);   // StandardMaterial3D uv1_scale/offset, carried over for world props (see world/world_toon.gd)
uniform vec2 uv_offset = vec2(0.0);
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.0;   // 0 = opaque, never discards; raise it only for an actual cutout texture

uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;   // where the lit/shadow band flips
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.12;   // width of that edge; 0 = razor-sharp
uniform vec4 shadow_tint : source_color = vec4(0.58, 0.58, 0.78, 1.0);   // multiplies ALBEDO in the shadow band

uniform float rim_strength : hint_range(0.0, 1.0) = 0.1;   // 0 disables the rim light entirely
uniform float rim_power : hint_range(0.5, 16.0) = 3.5;
uniform vec4 rim_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);

uniform float specular_strength : hint_range(0.0, 1.0) = 0.0;   // 0 disables the specular highlight band
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.9;
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Per-level tint (set by Main from the level's EnvironmentConfig): characters and
// props pick up a bit of the surrounding colour — e.g. cool teal inside the
// well — so they sit in the scene instead of looking pasted on. Amount 0 (the
// default, outdoors) changes nothing.
global uniform vec4 level_tint : source_color;
global uniform float level_tint_amount;

void fragment() {
	vec4 tex = texture(albedo_texture, UV * uv_scale + uv_offset);
	// Flatten: pull each texel's brightness toward mid-grey while keeping its hue,
	// so baked-in highlights stop reading as glossy plastic under the banded light.
	float tex_lum = max(dot(tex.rgb, vec3(0.299, 0.587, 0.114)), 0.04);
	tex.rgb *= mix(1.0, clamp(0.5 / tex_lum, 0.65, 1.5), texture_flatten);
	vec3 color = albedo_color.rgb;
	if (use_vertex_color) {
		color *= COLOR.rgb;
	}
	ALBEDO = tex.rgb * color * mix(vec3(1.0), level_tint.rgb, level_tint_amount);
	ALPHA = tex.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;   // no sky/ambient reflection sheen — the toon look has none

	if (rim_strength > 0.0) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), max(rim_power, 0.001));
		// Dimmer and tinted toward the level's colour in dark/tinted levels, so a cave
		// doesn't get a bright white outline glow on everything.
		vec3 rim_col = mix(rim_color.rgb, level_tint.rgb, level_tint_amount);
		float rim_scale = 1.0 - level_tint_amount * 0.8;
		EMISSION += rim_col * rim * rim_strength * rim_scale;
	}
}

void light() {
	// ATTENUATION already carries Godot's shadow factor (0 = fully shadowed,
	// 1 = fully lit, with a soft PCF-blurred gradient across the penumbra).
	// Folding it into the same value we band below means the shadow's own
	// edge gets quantized exactly like the light/dark terminator does,
	// instead of staying a smooth blur next to a hard band.
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, lit);

	// LIGHT_COLOR already includes the light's energy times PI (Godot's physical
	// light units); the built-in diffuse divides it back out, so we must too —
	// otherwise everything lights ~3x too bright and washes out to neon.
	vec3 light_rgb = LIGHT_COLOR / PI;
	vec3 lit_color = ALBEDO * light_rgb;
	vec3 shadowed_color = ALBEDO * shadow_tint.rgb * light_rgb;
	DIFFUSE_LIGHT += mix(shadowed_color, lit_color, band);

	if (specular_strength > 0.0) {
		vec3 half_vec = normalize(LIGHT + VIEW);
		float ndoth = clamp(dot(NORMAL, half_vec), 0.0, 1.0);
		float spec_band = smoothstep(specular_threshold - 0.02, specular_threshold + 0.02, ndoth) * band;
		SPECULAR_LIGHT += specular_color.rgb * spec_band * specular_strength;
	}
}
