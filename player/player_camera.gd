class_name CameraRig
extends Node3D
## Third-person orbit camera. Top-level node: follows `target` without inheriting rotation.

@export var mouse_sensitivity := 0.003
@export var follow_speed := 14.0
@export var base_distance := 6.0
@export var pitch_limits := Vector2(-1.2, 0.5)

var target: Node3D
var yaw := 0.0
var pitch := -0.35
var extra_distance := 0.0   ## set by the arena to frame the whole fight

var _arm: SpringArm3D
var _cam: Camera3D
var _shake := 0.0

func _ready() -> void:
	top_level = true
	_arm = SpringArm3D.new()
	_arm.spring_length = base_distance
	_arm.margin = 0.3
	# Only the ground/world layer and the arena's own circular wall push the
	# camera in — everything else (ordinary walls, props, enemies) the camera
	# clips straight through, so it never gets shoved in close to the player
	# (the x-ray silhouette keeps the player visible through that geometry
	# instead). Colliding with the world layer stops the camera dipping below
	# the floor; colliding with the arena wall stops it peeking outside the
	# fight's barrier.
	_arm.collision_mask = 1 | Arena.WALL_LAYER
	add_child(_arm)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 70.0
	_arm.add_child(_cam)
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
	_arm.spring_length = lerpf(_arm.spring_length, base_distance + extra_distance, 1.0 - exp(-4.0 * delta))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.4
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.4
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
