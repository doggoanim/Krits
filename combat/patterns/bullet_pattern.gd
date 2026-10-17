class_name BulletPattern
extends Resource
## Base class. Subclasses implement fire(); the enemy calls it every `interval` seconds.

@export var interval := 1.5
@export var bullet_speed := 7.0
@export var damage := 8.0
@export var pierces_shield := false

## origin: world position of the shooter. target: player. parent: node to add bullets to.
func fire(_origin: Vector3, _target: Vector3, _parent: Node, _step: int) -> void:
	pass

func _spawn(parent: Node, origin: Vector3, dir: Vector3, speed := -1.0, accel := 0.0) -> Bullet:
	var b := Bullet.new()
	b.damage = damage
	b.pierces_shield = pierces_shield
	b.velocity = dir.normalized() * (bullet_speed if speed < 0.0 else speed)
	b.accel = accel
	parent.add_child(b)
	b.global_position = origin
	return b
