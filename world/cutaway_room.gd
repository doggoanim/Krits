class_name CutawayRoom
extends Node3D
## Sits on an interior room's own root (alongside the "interior_level" group
## — see world/interior_room.tscn) and picks exactly one of its CutawayWall
## children to cut away each frame: whichever one's outward normal_axis is
## most directly aligned with the direction from the room to the camera —
## the wall most "in the way" between the camera and the room, i.e. the one
## the camera is effectively looking through. Every other panel stays
## solid, same as a normal wall, even if the camera also happens to be on
## its own outward side (which used to open up two walls at once at a
## corner view — see CutawayWall's own doc comment for why that decision
## moved up here instead of each wall judging only itself).
##
## If the camera is inside the room, nothing cuts away at all: a camera
## looking from inside is never genuinely outside any wall's plane, which
## _best_dot <= 0.0 below catches regardless of which wall scores "best".

var _walls: Array[CutawayWall] = []

func _ready() -> void:
	for c in get_children():
		if c is CutawayWall:
			_walls.append(c)

func _process(_delta: float) -> void:
	if _walls.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_cut_away_only(null)
		return

	var to_cam := cam.global_position - global_position
	if to_cam.length_squared() < 0.0001:
		return   # camera is sitting right on the room's own origin — keep last frame's state
	to_cam = to_cam.normalized()

	var best: CutawayWall = null
	var best_dot := 0.0   # a wall only ever qualifies if it's past 0 - genuinely facing the camera
	for w in _walls:
		var world_normal := (w.global_transform.basis * w.normal_axis).normalized()
		var d := world_normal.dot(to_cam)
		if d > best_dot:
			best_dot = d
			best = w
	_cut_away_only(best)

func _cut_away_only(chosen: CutawayWall) -> void:
	for w in _walls:
		w.set_cut_away(w == chosen)
