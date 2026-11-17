@tool
class_name HouseMount
extends RefCounted
## Shared plumbing for scripts that hang things on the (identical, imported) house
## models — see HouseDressing and HouseExtras. Parts are added as children without an
## owner, so they show in the editor but are never saved into the scene, and each part
## is tagged with a meta key so a rebuild can remove exactly its own earlier parts.

const DOOR_WALL_OFFSET := 0.33   ## from a Door_* node to the wall face in front of it
const DOOR_FLOOR_DROP := 1.0     ## a Door_* node sits this far above the floor

## Removes the parts a previous run tagged with `meta` from `house`.
static func clear(house: Node3D, meta: StringName) -> void:
	for child in house.get_children():
		if child.has_meta(meta):
			house.remove_child(child)
			child.queue_free()

## Adds `part` to the house (tagged `meta`), undoing the house's own scale so a squashed
## or stretched house doesn't squash what hangs on it.
static func place(house: Node3D, part: Node3D, meta: StringName, pos: Vector3, yaw := 0.0, extra_scale := 1.0) -> void:
	part.set_meta(meta, true)
	part.position = pos
	part.rotation.y = yaw
	var s := house.basis.get_scale()
	part.scale = Vector3(1.0 / maxf(s.x, 0.01), 1.0 / maxf(s.y, 0.01), 1.0 / maxf(s.z, 0.01)) * extra_scale
	house.add_child(part)

static func door_of(house: Node3D) -> Node3D:
	for child in house.get_children():
		if child is Node3D and String(child.name).begins_with("Door_"):
			return child as Node3D
	return null

## The front wall at x: its z (house space), and the floor height of the door it belongs to.
## Falls back to the Door_* node's own position when the model gives no wall there.
static func wall_z(house: Node3D, x: float, floor_y: float) -> float:
	var wall := RoofProbe.wall_front(house, x, 1.5, floor_y + 0.3, floor_y + 2.5)
	if is_nan(wall):
		var door := door_of(house)
		wall = door.position.z + DOOR_WALL_OFFSET if door != null else 0.0
	return wall
