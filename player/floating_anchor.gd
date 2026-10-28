class_name FloatingAnchor
extends Node3D
## A point that trails the player at a fixed offset with a little lag and a
## gentle bob, so anything parented to it looks like it's floating rather
## than bolted on. Position and facing each ease toward their target at their
## own speed; the pieces of worn gear are just children of one of these.

@export var position_follow := 14.0   ## higher = tighter (1/seconds-ish)
@export var turn_follow := 8.0
@export var bob_height := 0.025
@export var bob_speed := 2.2

var _bob_t := randf() * TAU

func _ready() -> void:
	top_level = true   # world-space: follows by script, not by inheriting the player's motion

## Snaps to the target immediately (spawn, teleport).
func snap_to(target_pos: Vector3, yaw: float) -> void:
	global_position = target_pos
	global_rotation = Vector3(0.0, yaw, 0.0)

## Call every frame with where the anchor *should* be. Returns the anchor's
## world velocity this frame (handy for swinging things hung off it).
func follow(target_pos: Vector3, yaw: float, delta: float) -> Vector3:
	_bob_t += delta * bob_speed
	target_pos += Vector3.UP * sin(_bob_t) * bob_height
	var before := global_position
	global_position = before.lerp(target_pos, 1.0 - exp(-position_follow * delta))
	global_rotation.y = lerp_angle(global_rotation.y, yaw, 1.0 - exp(-turn_follow * delta))
	return (global_position - before) / maxf(delta, 0.0001)
