class_name AimedPattern
extends BulletPattern
## Fan of bullets aimed at the player.

@export var count := 3
@export var spread := 18.0   ## degrees between bullets

func fire(origin: Vector3, target: Vector3, parent: Node, _step: int) -> void:
	var dir := target - origin
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	for i in count:
		var off := (i - (count - 1) * 0.5) * deg_to_rad(spread)
		_spawn(parent, origin, dir.rotated(Vector3.UP, off))
