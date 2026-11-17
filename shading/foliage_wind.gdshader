shader_type spatial;
render_mode cull_disabled;
// Pausable clock (see core/shader_clock.gd): TIME keeps running while the
// game is paused, so ShaderClock publishes how much of it was spent paused
// and we subtract that — animation freezes with the pause menu. (Unset, e.g.
// in the editor's own viewport, it's 0 and this is plain TIME.)
global uniform float time_offset;

// Held poses (see core/choppy.gd): 2 frames at 24 fps = 12 poses a second. Keep in sync.
const float STEP_SECONDS = 0.083333;
float held_time() {
	return floor((TIME - time_offset) / STEP_SECONDS) * STEP_SECONDS;
}
// Where the player's feet are, and how far their stepping reaches (0 = nobody is
// pushing anything). Published every frame by player/foliage_steps.gd.
global uniform vec3 foliage_pusher_pos;
global uniform float foliage_pusher_radius;
// Wind-swaying foliage material. Same albedo/colour handling as imported .glb
// materials, but lit with the project's toon lighting (shading/toon_light.gdshaderinc:
// banded sun shadows, smooth point lights) so trees and grass match the toon-shaded
// houses and characters. See world/foliage_wind.gd for how a prop gets wired up to
// this — per-instance wind tunables live there, exported on that node, since that's
// the actual node in the saved scene; this shader only knows about the numbers it's
// handed.
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
#include "res://shading/toon_light.gdshaderinc"

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

// Stepping through it: 0 = this prop ignores the player (trees); 1 = grass-like, flattens
// and leans away from the player's feet. `rustle` (0..1) is a quick shake pushed by
// world/foliage_wind.gd while the player is moving inside a bush.
uniform float step_bend = 0.0;
uniform float rustle = 0.0;
uniform float prop_height = 1.0;   // this prop's own height in the world (m), so a flower flattens as much as a tall grass blade does

// Per-instance tint applied ONLY to strongly-green texels (leaves), so a tree's
// trunk keeps its own colour. White = no change. See world/tree_variation.gd.
uniform vec3 green_tint : source_color = vec3(1.0);

const float MAX_BEND = 1.05;   // radians (about 60 degrees) a fully-trampled prop tips over

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(VERTEX.y - base_y, 0.0);
	// Phase depends on world position (not just TIME) so instances of the
	// same mesh scattered around the level don't all sway in lockstep — each
	// one samples a slightly different point of the same slow-moving "gust"
	// field instead.
	float phase = held_time() * wind_speed + dot(world_pos.xz, vec2(wind_scale));
	float sway = height * wind_strength * gust;
	VERTEX.x += sin(phase) * sway;
	VERTEX.z += cos(phase * 0.7) * sway * 0.6;

	if (rustle > 0.001) {
		float t = held_time() * 24.0 + phase * 2.0;
		VERTEX.x += sin(t) * height * 0.09 * rustle;
		VERTEX.z += cos(t * 1.3) * height * 0.07 * rustle;
	}

	if (step_bend > 0.0 && foliage_pusher_radius > 0.0) {
		// The whole prop tips over away from the player's feet as one piece, hinged at its base:
		// the direction and strength come from the prop's ORIGIN, not each vertex, so a flower's
		// head can't be pushed one way on one side and the other way on the other (which squashed
		// and wrapped it), and the rotation keeps its length instead of pressing it flat.
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 base = MODEL_MATRIX[3].xyz;
		vec2 away = base.xz - foliage_pusher_pos.xz;
		float near = 1.0 - smoothstep(0.0, foliage_pusher_radius, length(away));
		near *= 1.0 - smoothstep(0.9, 1.8, abs(base.y - foliage_pusher_pos.y));   // only stepping on what is at your feet
		float world_h = height * length(MODEL_MATRIX[1].xyz);                  // height above the mesh's own base, so any pivot works
		float up = clamp(world_h / max(prop_height, 0.05), 0.0, 1.0);
		float angle = near * step_bend * MAX_BEND * mix(0.55, 1.0, up);       // the tip leans a little further than the stem
		vec2 dir = away / max(length(away), 0.0001);
		vec3 axis = normalize(vec3(-dir.y, 0.0, dir.x));                       // horizontal, perpendicular to the lean direction
		vec3 rel = wp - base;
		float c = cos(angle);
		float sn = sin(angle);
		rel = rel * c + cross(axis, rel) * sn + axis * dot(axis, rel) * (1.0 - c);   // Rodrigues rotation about the hinge
		VERTEX = (inverse(MODEL_MATRIX) * vec4(base + rel, 1.0)).xyz;
	}
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 color = albedo_color.rgb;
	if (use_vertex_color) {
		color *= COLOR.rgb;
	}
	vec3 albedo = tex.rgb * color;
	float leafness = smoothstep(0.03, 0.25, albedo.g - max(albedo.r, albedo.b));
	albedo = mix(albedo, albedo * green_tint, leafness);
	ALBEDO = albedo;
	ALPHA = tex.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.0;   // toon look: no shiny sheen on leaves
}

// Same banded sun / smooth point-light lighting as the rest of the world
// (shading/toon_light.gdshaderinc), so trees and grass match the houses.
void light() {
	float band;
	DIFFUSE_LIGHT += toon_diffuse(ALBEDO, NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, band);
}
