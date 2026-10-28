shader_type spatial;
render_mode cull_disabled;
// Pausable clock (see core/shader_clock.gd): TIME keeps running while the
// game is paused, so ShaderClock publishes how much of it was spent paused
// and we subtract that — animation freezes with the pause menu. (Unset, e.g.
// in the editor's own viewport, it's 0 and this is plain TIME.)
global uniform float time_offset;
// Wind-swaying foliage material. Not the project's toon shader
// (shading/toon.gdshader) — world foliage props (grass, trees; see
// world/chesburg.tscn's Props/Trees and Props/eyecandies) are unmodified
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
// Vertex sway wants "local height above the ground", which most foliage
// assets here give for free (mesh origin planted at the base, so VERTEX.y
// already IS that height) — but not every imported asset follows that
// convention (a flower card authored with its pivot at the center or top,
// say), and for one of those almost the entire mesh could read as height 0
// and barely sway at all. base_y corrects for that: FoliageWind.gd measures
// each mesh's own local AABB once at setup and hands its lowest Y down here,
// so height is always relative to wherever the mesh ACTUALLY starts,
// whatever the pivot convention of the source asset happened to be.
// wind_strength is in world units of sway per world unit of that height, so
// the same value naturally reads as a small flutter on short grass and a
// visibly bigger sway on a tall tree's crown; tune per-instance via
// FoliageWind's exports if a particular prop needs to look calmer or wilder
// than that default scaling.
uniform float base_y = 0.0;   // this mesh's own local AABB min Y — see world/foliage_wind.gd

uniform sampler2D albedo_texture : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_vertex_color = false;   // see shading/toon.gdshader's identical parameter
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.0;   // for leaf/blade cutout textures
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

uniform float wind_strength = 0.06;   // world-space sway per world unit of local VERTEX.y
uniform float wind_speed = 1.5;
uniform float wind_scale = 0.3;       // world-space frequency of the sway — lower = broader, slower gusts

// Live multiplier on top of wind_strength, pushed every frame by
// world/foliage_wind.gd from world/wind_gusts.gd's shared gust field — a
// plain per-prop idle sway the rest of the time, periodically swelling as a
// gust sweeps through. Not something this shader computes itself: it has no
// idea what time of day or weather it is, FoliageWind just hands it a number.
uniform float gust = 1.0;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(VERTEX.y - base_y, 0.0);
	// Phase depends on world position (not just TIME) so instances of the
	// same mesh scattered around the level don't all sway in lockstep — each
	// one samples a slightly different point of the same slow-moving "gust"
	// field instead.
	float phase = (TIME - time_offset) * wind_speed + dot(world_pos.xz, vec2(wind_scale));
	float sway = height * wind_strength * gust;
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
