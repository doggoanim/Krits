// Shared toon lighting maths, #included by toon_core.gdshaderinc (characters and
// props) and foliage_wind.gdshader (trees, grass), so everything in the world
// bands light and shadow the same way. Call toon_diffuse() from light().

uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;   // where the lit/shadow band flips
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.12;   // width of that edge; 0 = razor-sharp
uniform vec4 lit_tint : source_color = vec4(1.0, 0.96, 0.86, 1.0);   // extra warmth on the sunlit band (the banded sun otherwise lights surfaces flat and a bit bright, which washes the sun colour out)
uniform vec4 shadow_tint : source_color = vec4(0.58, 0.58, 0.78, 1.0);   // multiplies ALBEDO in the shadow band

// Returns this light's diffuse contribution and, through `band`, the 0..1
// lit amount (so callers can gate a specular highlight on it).
// - Directional light (the sun): cel-banded; shadows pick up shadow_tint.
// - Point/spot lights: smooth falloff — banding them turns round light pools
//   into hard, stair-stepped discs.
// ATTENUATION already carries the shadow factor, so a shadow's edge is
// quantised exactly like the light/dark terminator.
vec3 toon_diffuse(vec3 albedo, vec3 normal, vec3 light_dir, vec3 light_color, float atten, bool directional, out float band) {
	float lit = clamp(dot(normal, light_dir), 0.0, 1.0) * atten;
	// LIGHT_COLOR includes the light's energy times PI (Godot's physical light
	// units); the built-in diffuse divides it back out, so we must too.
	vec3 light_rgb = light_color / PI;
	if (!directional) {
		band = lit;
		return albedo * light_rgb * lit;
	}
	band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, lit);
	return mix(albedo * shadow_tint.rgb * light_rgb, albedo * light_rgb * lit_tint.rgb, band);
}
