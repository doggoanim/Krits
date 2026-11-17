@tool
class_name HouseMount
extends RefCounted
## Shared plumbing for scripts that hang things on the (identical, imported) house models —
## see HouseExtras: finding a house's door and the front wall in front of it.

const DOOR_WALL_OFFSET := 0.33   ## from a Door_* node to the wall face in front of it
const DOOR_FLOOR_DROP := 1.0     ## a Door_* node sits this far above the floor

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
