class_name CameraRig
extends Node3D
## Third-person orbit camera. Top-level node: follows `target` without inheriting rotation.
##
## Wall avoidance: SpringArm3D is kept purely as a sensor (never holds the
## camera, so its own automatic child-repositioning never fires) — each
## frame we read get_hit_length() for the safe distance and smooth our own
## `_distance` toward it before moving the actual Camera3D. Consuming the
## sensed distance this way, instead of letting SpringArm3D reposition its
## children directly, is what adds the smoothing: SpringArm3D's own
## collision shortening is otherwise instant, which reads as the camera
## abruptly "zooming in" the moment you brush past a wall.

@export var mouse_sensitivity := 0.003
@export var follow_speed := 14.0
@export var base_distance := 6.0
@export var pitch_limits := Vector2(-1.2, 0.5)
@export var min_distance := 0.8       ## never pull in closer than this, even against a wall
@export var pull_in_speed := 16.0     ## smoothing rate when the wall is closer than the current distance
@export var ease_out_speed := 5.0     ## smoothing rate when pulling back out toward base_distance

var target: Node3D
var yaw := 0.0
var pitch := -0.35
var extra_distance := 0.0   ## set by the arena to frame the whole fight

var _arm: SpringArm3D   ## sensor only — not a parent of _cam, never positions anything itself
var _cam: Camera3D
var _shake := 0.0
var _distance := 0.0

func _ready() -> void:
	top_level = true
	_distance = base_distance
	_arm = SpringArm3D.new()
	_arm.collision_mask = 1
	_arm.margin = 0.3
	add_child(_arm)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 70.0
	add_child(_cam)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, pitch_limits.x, pitch_limits.y)

func get_camera() -> Camera3D:
	return _cam

func snap() -> void:
	if target:
		global_position = target.global_position + Vector3.UP * 1.4

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position + Vector3.UP * 1.4, 1.0 - exp(-follow_speed * delta))
	rotation = Vector3(pitch, yaw, 0.0)

	var desired := base_distance + extra_distance
	_arm.spring_length = desired
	var safe := clampf(_arm.get_hit_length(), min_distance, desired)
	var rate := pull_in_speed if safe < _distance else ease_out_speed
	_distance = lerpf(_distance, safe, 1.0 - exp(-rate * delta))
	_cam.position = Vector3(0.0, 0.0, -_distance)

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.4
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.4
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
