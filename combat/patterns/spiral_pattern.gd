class_name SpiralPattern
extends BulletPattern
## Multi-arm spiral that keeps turning. Accelerating bullets make it nastier.

@export var arms := 3
@export var step_angle := 14.0
@export var accelerate := 0.0

func fire(origin: Vector3, target: Vector3, parent: Node, step: int) -> void:
	for i in arms:
		var a := TAU * i / arms + deg_to_rad(step_angle) * step
		var dir := _tilt_toward_height(Vector3(sin(a), 0.0, cos(a)), origin, target)
		_spawn(parent, origin, dir, -1.0, accelerate)
