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
var _yaw := 0.0

func _ready() -> void:
	top_level = true   # world-space: follows by script, not by inheriting the player's motion

## Snaps to the target immediately (spawn, teleport).
func snap_to(target_pos: Vector3, yaw: float) -> void:
	global_position = target_pos
	_yaw = yaw
	global_basis = Basis(Vector3.UP, yaw)

## Call every frame with where the anchor *should* be. Returns the anchor's
## world velocity this frame (handy for swinging things hung off it).
## `tilt` is an extra world-space rotation applied on top of the facing (the
## wearer's torso leaning/rolling), identity for none.
func follow(target_pos: Vector3, yaw: float, delta: float, tilt := Basis.IDENTITY) -> Vector3:
	_bob_t += delta * bob_speed
	target_pos += Vector3.UP * sin(_bob_t) * bob_height
	var before := global_position
	global_position = before.lerp(target_pos, 1.0 - exp(-position_follow * delta))
	_yaw = lerp_angle(_yaw, yaw, 1.0 - exp(-turn_follow * delta))
	global_basis = tilt * Basis(Vector3.UP, _yaw)
	return (global_position - before) / maxf(delta, 0.0001)
