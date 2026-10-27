class_name CutawayWall
extends StaticBody3D
## A wall/ceiling panel that hides its own mesh — but keeps its collision, so
## the player still can't walk through it — whenever the active camera ends
## up on its OUTWARD side. This is the actual "see into the room from
## outside" dollhouse trick: cull_mode-FRONT (see interior_room.tscn's own
## material setup) only ever shows SOME opaque face, never a transparent
## one, so a camera outside a room built that way just sees a solid-looking
## wall rendered backwards — not what's inside it. Hiding the mesh outright
## is what actually opens the room up to view from outside, while it still
## reads as a normal enclosed room from inside, since from in there the
## camera is never on this panel's outward side.
##
## `normal_axis` is this panel's own outward-facing LOCAL axis — e.g.
## Vector3.BACK (0,0,1) for a wall built flush against the room's own +Z
## side, Vector3.UP for the ceiling. Multiplied through this node's own
## global_transform.basis each frame, so it keeps pointing the right way
## even if the whole room is rotated or moved.
##
## The mesh itself stays `visible = true` at all times — only its
## `cast_shadow` mode flips, between SHADOWS_ONLY (renders no color, so the
## camera sees straight through it, but still occludes) and ON (rendered
## normally). That's deliberate, not just a smaller way to hide it: a plain
## `visible = false` drops the panel from the shadow pass too, so the
## room's own Lamp would start spilling its light straight out through the
## open side into the outside void the moment a wall disappeared — visibly
## changing how the room itself looks depending on where the camera stands,
## which is backwards (the interior's lighting should read the same
## regardless of which wall the camera currently has cut away).
## SHADOWS_ONLY keeps the panel fully "in" the scene for lighting purposes
## while making it render nothing to color, which is exactly the split we
## need.

@export var normal_axis := Vector3.BACK

## Every CutawayWall's own physics RID, for PlayerXray to exclude from its
## camera->player raycast (see that script's own doc comment) — a wall hiding
## its mesh to let the camera see into the room still keeps its collision
## (so the player can't walk through it), and without this exclusion that
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

func _process(_delta: float) -> void:
	if _mesh == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var world_normal := (global_transform.basis * normal_axis).normalized()
	var to_cam := cam.global_position - global_position
	# Camera on (or past) the outward side -> render nothing (but keep
	# casting a shadow), so it can see through to the room without the
	# room's own lighting changing. Camera still on the inward side -> show,
	# same as a normal wall.
	var outward := to_cam.dot(world_normal) <= 0.0
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
		if outward else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
