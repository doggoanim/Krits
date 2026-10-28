class_name CameraRig
extends Node3D
## Third-person orbit camera. Top-level node: follows `target` without inheriting rotation.

## Physics layer 8, "camera_push" in project.godot's layer_names (so it shows
## a real label instead of a blank checkbox in the Inspector's Collision
## section) — anything the camera's spring arm should actually be pushed out
## by, as opposed to generic world geometry (layer 1, "world") which the
## camera is allowed to clip through, relying on the player's x-ray
## silhouette to stay visible instead. Originally just walkable floors (see
## TestLevel._box()'s `is_floor` param) so the camera doesn't dip below the
## ground, but the same bit works for anything else that should shove the
## camera away rather than let it clip in — a tree or house trunk, say: tick
## this layer alongside whatever layer it's already on (still keep layer 1
## too, so normal raycasts/physics still see it as world geometry).
const GROUND_LAYER := 1 << 7

## Base look speed; the player's Settings > Controls sensitivity multiplies it.
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
var _sens_scale := 1.0     ## cached from Settings (controls/camera_sens)
var _pitch_dir := 1.0      ## -1 when Settings has invert-Y on

# Conversation focus (see DialogueStage): the camera eases toward framing the
# speaker and eases back to the exact view it left.
const FOCUS_TIME := 0.6
const FOCUS_YAW_OFFSET := 0.32      ## swings the view off-axis so the speaker sits to one side
const FOCUS_PITCH := -0.12
const FOCUS_PULL_IN := 1.0          ## metres the camera moves closer while focused
var _focus_on := false
var _focus_weight := 0.0            ## 0 = normal view, 1 = fully framing the speaker
var _focus_node: Node3D
var _focus_point := Vector3.ZERO
var _saved_yaw := 0.0
var _saved_pitch := 0.0
var _focus_yaw := 0.0

func _ready() -> void:
	top_level = true
	_arm = SpringArm3D.new()
	_arm.spring_length = base_distance
	_arm.margin = 0.3
	# A sphere, not SpringArm3D's default bare raycast: a ray only tests the
	# exact center line out to the camera, so geometry near the edge of what
	# the camera actually sees (floors at a steep downward pitch, the arena
	# wall seen at a glancing angle) could still clip into frame even while
	# the center line itself read clear. Shape-casting a sphere the rough
	# size of the camera's near plane catches that.
	var probe := SphereShape3D.new()
	probe.radius = 0.35
	_arm.shape = probe
	# Only walkable ground and the arena's own circular wall push the camera
	# in — everything else (ordinary walls, props, enemies, all sharing the
	# generic "world" layer) the camera clips straight through, so it never
	# gets shoved in close to the player (the x-ray silhouette keeps the
	# player visible through that geometry instead). Colliding with the
	# ground layer stops the camera dipping below the floor; colliding with
	# the arena wall stops it peeking outside the fight's barrier.
	_arm.collision_mask = GROUND_LAYER | Arena.WALL_LAYER
	add_child(_arm)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 70.0
	_arm.add_child(_cam)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Settings.changed.connect(_on_setting_changed)
	_read_settings()

func _read_settings() -> void:
	_sens_scale = Settings.get_value(&"controls/camera_sens")
	_pitch_dir = -1.0 if Settings.get_value(&"controls/invert_y") else 1.0
	_cam.far = Settings.get_value(&"display/render_distance")

func _on_setting_changed(_key: StringName) -> void:
	_read_settings()

## Starts framing `node` (looking at `point`, in world space, for the aim).
func begin_focus(node: Node3D, point: Vector3) -> void:
	if target == null:
		return
	_focus_node = node
	_focus_point = point
	_saved_yaw = yaw
	_saved_pitch = pitch
	var d := point - target.global_position
	_focus_yaw = atan2(-d.x, -d.z) + FOCUS_YAW_OFFSET
	# Take the shortest way round from the current yaw.
	_focus_yaw = _saved_yaw + angle_difference(_saved_yaw, _focus_yaw)
	_focus_on = true

func end_focus() -> void:
	_focus_on = false

func _update_focus(delta: float) -> float:
	var goal := 1.0 if _focus_on else 0.0
	_focus_weight = move_toward(_focus_weight, goal, delta / FOCUS_TIME)
	var k := smoothstep(0.0, 1.0, _focus_weight)
	if _focus_weight > 0.0 or _focus_on:
		yaw = lerpf(_saved_yaw, _focus_yaw, k)
		pitch = lerpf(_saved_pitch, FOCUS_PITCH, k)
	return k

func _unhandled_input(event: InputEvent) -> void:
	if _focus_on or _focus_weight > 0.0:
		return   # the conversation owns the camera until it has eased back
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := mouse_sensitivity * _sens_scale
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * _pitch_dir, pitch_limits.x, pitch_limits.y)

func get_camera() -> Camera3D:
	return _cam

func snap() -> void:
	if target:
		global_position = target.global_position + Vector3.UP * 1.4

func shake(amount: float) -> void:
	if not Settings.get_value(&"accessibility/screen_shake"):
		return
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	var focus := _update_focus(delta)
	if target:
		var anchor := target.global_position + Vector3.UP * 1.4
		if focus > 0.0 and is_instance_valid(_focus_node):
			anchor = anchor.lerp((target.global_position + _focus_point) * 0.5, focus * 0.6)
		global_position = global_position.lerp(anchor, 1.0 - exp(-follow_speed * delta))
	rotation = Vector3(pitch, yaw, 0.0)
	_arm.spring_length = lerpf(_arm.spring_length, base_distance + extra_distance - FOCUS_PULL_IN * focus, 1.0 - exp(-4.0 * delta))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.4
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.4
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
