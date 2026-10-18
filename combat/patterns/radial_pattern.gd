class_name RadialPattern
extends BulletPattern
## Ring of bullets, rotated by `twist` degrees every shot.

@export var count := 12
@export var twist := 7.0

func fire(origin: Vector3, target: Vector3, parent: Node, step: int) -> void:
	for i in count:
		var a := TAU * i / count + deg_to_rad(twist) * step
		var dir := _tilt_toward_height(Vector3(sin(a), 0.0, cos(a)), origin, target)
		_spawn(parent, origin, dir)
