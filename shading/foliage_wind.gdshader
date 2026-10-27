shader_type spatial;
render_mode cull_disabled;
// Wind-swaying foliage material. Not the project's toon shader
// (shading/toon.gdshader) — world foliage props (grass, trees; see
// world/hometown.tscn's Props/Trees and Props/eyecandies) are unmodified
// imported .glb materials rendered with Godot's ordinary PBR lighting, so
// this is a drop-in replacement for THAT look (same albedo/roughness/
// metallic, default diffuse+specular lighting via light() left untouched),
// not a different style. See world/foliage_wind.gd for how a prop gets
// wired up to this — per-instance wind tunables live there, exported on
// that node, since that's the actual node in the saved scene; this shader
// only knows about the numbers it's handed.
//
// cull_disabled: grass blades and leaf cards in this project are typically
// thin, single-sided planes that still need to be visible from both sides
// once they're swaying instead of sitting rigidly flat-on to the camera.
// Trees/trunks render fine double-sided too (same geometry, just also draws
// backfaces) — the trivial extra fill-rate cost is a non-issue for
// prop-scale meshes, so it's simplest to always disable culling here rather
// than add a second variant shader just for that one flag.
//
// Vertex sway relies on the convention every foliage asset here already
// follows: the mesh's own origin sits at its base (planted at Y=0), so
// VERTEX.y is already "local height above the ground" with no extra offset
// needed — taller parts (a blade's tip, a branch's end) sway further than
// the root without any per-asset calibration. wind_strength is in world
// units of sway per world unit of local height, so the same value naturally
// reads as a small flutter on short grass and a visibly bigger sway on a
// tall tree's crown; tune per-instance via FoliageWind's exports if a
// particular prop needs to look calmer or wilder than that default scaling.

uniform sampler2D albedo_texture : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_vertex_color = false;   // see shading/toon.gdshader's identical parameter
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.0;   // for leaf/blade cutout textures
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

uniform float wind_strength = 0.06;   // world-space sway per world unit of local VERTEX.y
uniform float wind_speed = 1.5;
uniform float wind_scale = 0.3;       // world-space frequency of the sway — lower = broader, slower gusts

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(VERTEX.y, 0.0);
	// Phase depends on world position (not just TIME) so instances of the
	// same mesh scattered around the level don't all sway in lockstep — each
	// one samples a slightly different point of the same slow-moving "gust"
	// field instead.
	float phase = TIME * wind_speed + dot(world_pos.xz, vec2(wind_scale));
	float sway = height * wind_strength;
	VERTEX.x += sin(phase) * sway;
	VERTEX.z += cos(phase * 0.7) * sway * 0.6;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 color = albedo_color.rgb;
	if (use_vertex_color) {
		color *= COLOR.rgb;
	}
	ALBEDO = tex.rgb * color;
	ALPHA = tex.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
