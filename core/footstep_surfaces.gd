class_name FootstepSurfaces
extends RefCounted
## Maps whatever the player's feet are standing on to a Surface, for
## PlayerAudio.play_footstep() to pick the matching sound set.
##
## Most world geometry here is imported .glb scenes (grass_terrain.glb,
## dirt_terrain.glb, rock_terrain.glb, ...) rather than hand-placed
## collision shapes you could attach a script or an export var to directly —
## there's no per-object Inspector field for "surface type" by default. So
## detection works in two layers, checked in order:
##
## 1. GROUP OVERRIDE (explicit, highest priority): add the floor collider —
##    or any of its ancestors, e.g. the whole instanced scene's root — to a
##    group named "surface_<name>" (see GROUP_NAMES below, e.g.
##    "surface_dirt") in the editor. Use this for anything the automatic
##    guess below gets wrong, or for a mesh whose name doesn't say what it
##    looks like.
## 2. NAME GUESS (automatic, zero editor work): falls back to scanning the
##    collider's own node name and its owning scene's file name (set
##    automatically when a .glb is instanced) for a keyword — this already
##    works for free for every asset following the project's existing
##    *_terrain.glb / grass_*, dirt_*, rock_* naming convention.
##
## Falls back to GRASS (not a NONE/unknown surface) if nothing matches at
## all, since that's the only sound set actually recorded so far — see
## PlayerAudio.FOOTSTEP_SFX_BY_SURFACE. Adding a new surface: add it to
## Surface, GROUP_NAMES and NAME_KEYWORDS below, then give PlayerAudio a
## sound set for it.

enum Surface { GRASS, DIRT, ROCK }

const GROUP_NAMES := {
	Surface.GRASS: &"surface_grass",
	Surface.DIRT: &"surface_dirt",
	Surface.ROCK: &"surface_rock",
}

## Each surface's list of substrings to look for (case-insensitive) in a
## name. Checked in Surface enum order, so put a more specific word earlier
## if two surfaces might ever share a substring.
const NAME_KEYWORDS := {
	Surface.GRASS: ["grass"],
	Surface.DIRT: ["dirt"],
	Surface.ROCK: ["rock", "stone"],
}

## `collider` is whatever CollisionObject3D (or any Node) a floor raycast hit
## — see Player.floor_collider_below(). Null is treated as GRASS, same as
## "nothing matched".
static func detect(collider: Node) -> Surface:
	if collider == null:
		return Surface.GRASS
	var by_group := _from_groups(collider)
	if by_group != null:
		return by_group
	return _from_names(collider)

static func _from_groups(node: Node) -> Variant:
	var n := node
	while n != null:
		for surface: Surface in GROUP_NAMES:
			if n.is_in_group(GROUP_NAMES[surface]):
				return surface
		n = n.get_parent()
	return null

static func _from_names(node: Node) -> Surface:
	var n := node
	while n != null:
		var haystack := String(n.name).to_lower()
		if n is Node3D:
			var scene_path := (n as Node3D).scene_file_path
			if not scene_path.is_empty():
				haystack += " " + scene_path.get_file().to_lower()
		for surface: Surface in NAME_KEYWORDS:
			for keyword: String in NAME_KEYWORDS[surface]:
				if haystack.contains(keyword):
					return surface
		n = n.get_parent()
	return Surface.GRASS
