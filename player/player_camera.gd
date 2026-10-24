class_name CameraRig
extends Node3D
## Third-person orbit camera. Top-level node: follows `target` without inheriting rotation.

## Physics layer 8 — walkable floor/ground surfaces only, *not* generic world
## geometry like walls or props (those all share layer 1, "world", with no
## way to tell them apart by layer alone). A level's flat, walkable surfaces
## should carry this bit too (see TestLevel._box()'s `is_floor` param) so the
## camera collides with the ground under it without also bumping into every
## ordinary wall that happens to sit on the same general "world" layer.
const GROUND_LAYER := 1 << 7

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
	# TrampleMap's top-down capture camera renders TrampleMarker meshes on
	# this one layer so grass can bend away from movers — the real game
	# camera must never show them.
	_cam.cull_mask = (1 << 20) - 1 & ~TrampleMap.TRAMPLE_LAYER
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
