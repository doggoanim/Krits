shader_type spatial;
render_mode depth_draw_opaque;
// Writing to ALPHA below (even though it's normally 1.0) makes Godot treat
// this as a transparent material by default, which skips writing to the
// depth buffer — that breaks CelOutline's inverted-hull outline technique,
// since the real mesh then fails to occlude the black outline shell behind
// it and the whole character renders as a solid black silhouette instead of
// a thin rim. depth_draw_opaque forces normal depth writing regardless of
// the alpha value, restoring correct occlusion.
//
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
// Usage: duplicate shading/toon_material.tres (or make a fresh
// ShaderMaterial pointed at this shader) and assign it as a mesh surface's
// material/material override — the player model, enemies, world props,
// anything. ModelUtil.apply_cel_shading() does this automatically for any
// rigged character model (see core/model_util.gd), one dedicated material
// per mesh surface so each can be tinted independently (flash-on-hit, slime
// tint, ...) via ModelUtil.get_tint()/set_tint().

uniform sampler2D albedo_texture : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;   // where the lit/shadow band flips
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.05;   // width of that edge; 0 = razor-sharp
uniform vec4 shadow_tint : source_color = vec4(0.6, 0.6, 0.75, 1.0);   // multiplies ALBEDO in the shadow band

uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;   // 0 disables the rim light entirely
uniform float rim_power : hint_range(0.5, 16.0) = 4.0;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float specular_strength : hint_range(0.0, 1.0) = 0.0;   // 0 disables the specular highlight band
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.9;
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	ALPHA = tex.a * albedo_color.a;

	if (rim_strength > 0.0) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), max(rim_power, 0.001));
		EMISSION += rim_color.rgb * rim * rim_strength;
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

	vec3 lit_color = ALBEDO * LIGHT_COLOR;
	vec3 shadowed_color = ALBEDO * shadow_tint.rgb * LIGHT_COLOR;
	DIFFUSE_LIGHT += mix(shadowed_color, lit_color, band);

	if (specular_strength > 0.0) {
		vec3 half_vec = normalize(LIGHT + VIEW);
		float ndoth = clamp(dot(NORMAL, half_vec), 0.0, 1.0);
		float spec_band = smoothstep(specular_threshold - 0.02, specular_threshold + 0.02, ndoth) * band;
		SPECULAR_LIGHT += specular_color.rgb * spec_band * specular_strength;
	}
}
