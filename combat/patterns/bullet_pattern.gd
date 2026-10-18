class_name BulletPattern
extends Resource
## Base class. Subclasses implement fire(); the enemy calls it every `interval` seconds.

const MAX_HEIGHT_TILT := 65.0   ## degrees; caps how far a ring/spiral tilts toward an overhead target

@export var interval := 1.5
@export var bullet_speed := 7.0
@export var damage := 8.0
@export var pierces_shield := false

## origin: world position of the shooter. target: player. parent: node to add bullets to.
func fire(_origin: Vector3, _target: Vector3, _parent: Node, _step: int) -> void:
	pass

## Tilts a horizontal (y = 0) unit direction up or down so ring/spiral-style
## patterns climb toward the target's actual height instead of staying locked
## to the shooter's own flat plane — otherwise orb-combo juggling in the air is
## free cover. Clamped to MAX_HEIGHT_TILT so a target directly overhead still
## leaves a dodgeable spread instead of every bullet collapsing onto one line.
func _tilt_toward_height(dir_flat: Vector3, origin: Vector3, target: Vector3) -> Vector3:
	var to_target := target - origin
	var horiz_dist := Vector2(to_target.x, to_target.z).length()
	var pitch := clampf(atan2(to_target.y, maxf(horiz_dist, 0.01)), -deg_to_rad(MAX_HEIGHT_TILT), deg_to_rad(MAX_HEIGHT_TILT))
	return (dir_flat * cos(pitch) + Vector3.UP * sin(pitch)).normalized()

func _spawn(parent: Node, origin: Vector3, dir: Vector3, speed := -1.0, accel := 0.0) -> Bullet:
	var b := Bullet.new()
	b.damage = damage
	b.pierces_shield = pierces_shield
	b.velocity = dir.normalized() * (bullet_speed if speed < 0.0 else speed)
	b.accel = accel
	parent.add_child(b)
	b.global_position = origin
	return b
