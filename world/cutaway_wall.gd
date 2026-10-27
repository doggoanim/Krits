class_name CutawayWall
extends StaticBody3D
## A wall/ceiling panel that can be told to "cut away" — render no color (so
## a camera outside the room sees straight through it) while still keeping
## its collision (so the player can't walk through it) AND still casting a
## shadow (see the cast_shadow note below). This is the actual "see into the
## room from outside" dollhouse trick: cull_mode-FRONT (see
## interior_room.tscn's own material setup) only ever shows SOME opaque
## face, never a transparent one, so a camera outside a room built that way
## just sees a solid-looking wall rendered backwards — not what's inside it.
##
## This script only ever reacts to set_cut_away() — it has no opinion of its
## own about WHEN that should happen. That decision belongs to CutawayRoom
## (world/cutaway_room.gd), the room's own parent node, which looks at all
## of its CutawayWall children together each frame and picks at most one —
## whichever is most directly between the camera and the room — to cut
## away. Deciding that per-wall, independently, used to mean two walls could
## open up at once at a corner view; CutawayRoom picks a single winner.
##
## `normal_axis` is this panel's own outward-facing LOCAL axis — e.g.
## Vector3.BACK (0,0,1) for a wall built flush against the room's own +Z
## side, Vector3.UP for the ceiling. CutawayRoom reads this (multiplied
## through this node's own global_transform.basis, so it keeps pointing the
## right way even if the whole room is rotated or moved) to score each wall
## by how directly it faces the camera.

@export var normal_axis := Vector3.BACK

## Every CutawayWall's own physics RID, for PlayerXray to exclude from its
## camera->player raycast (see that script's own doc comment) — a wall cut
## away to let the camera see into the room still keeps its collision (so
## the player can't walk through it), and without this exclusion that
## collision alone was enough to trip PlayerXray's halftone silhouette right
## on top of an already-correct cutaway view. Same static-registry idiom as
## WaterVolume.active.
static var active: Array[RID] = []

var _mesh: MeshInstance3D

func _ready() -> void:
	_mesh = find_child("Mesh", false, false) as MeshInstance3D
	active.append(get_rid())

func _exit_tree() -> void:
	active.erase(get_rid())

## The mesh stays `visible = true` at all times — only its `cast_shadow`
## mode flips, between SHADOWS_ONLY (renders no color, so the camera sees
## straight through it, but still occludes) and ON (rendered normally).
## That's deliberate, not just a smaller way to hide it: a plain
## `visible = false` drops the panel from the shadow pass too, so the
## room's own Lamp would start spilling its light straight out through the
## open side into the outside void the moment a wall cut away — visibly
## changing how the room itself looks depending on where the camera stands,
## which is backwards (the interior's lighting should read the same
## regardless of which wall is currently cut away). SHADOWS_ONLY keeps the
## panel fully "in" the scene for lighting purposes while rendering nothing
## to color, which is exactly the split we need.
func set_cut_away(cut_away: bool) -> void:
	if _mesh == null:
		return
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
		if cut_away else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
