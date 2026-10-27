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

@export var normal_axis := Vector3.BACK

var _mesh: MeshInstance3D

func _ready() -> void:
	_mesh = find_child("Mesh", false, false) as MeshInstance3D

func _process(_delta: float) -> void:
	if _mesh == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var world_normal := (global_transform.basis * normal_axis).normalized()
	var to_cam := cam.global_position - global_position
	# Camera on (or past) the outward side -> hide, so it can see through to
	# the room. Camera still on the inward side -> show, same as a normal wall.
	_mesh.visible = to_cam.dot(world_normal) <= 0.0
