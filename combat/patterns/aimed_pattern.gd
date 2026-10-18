class_name AimedPattern
extends BulletPattern
## Fan of bullets aimed at the player.

@export var count := 3
@export var spread := 18.0   ## degrees between bullets

func fire(origin: Vector3, target: Vector3, parent: Node, _step: int) -> void:
	# Full 3D direction (keeps the height difference) so bullets actually climb
	# toward the player while they're airborne — orb-combo juggling isn't free
	# cover anymore. Rotating the spread around UP only changes yaw, so each
	# fan bullet keeps aiming at the player's height, just offset sideways.
	var dir := target - origin
	if dir.length() < 0.01:
		return
	for i in count:
		var off := (i - (count - 1) * 0.5) * deg_to_rad(spread)
		_spawn(parent, origin, dir.rotated(Vector3.UP, off))
