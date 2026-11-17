@tool
class_name Chickens
extends Node3D
## A few hens pottering about a yard: they walk to a spot, peck at the ground, wander on,
## and scatter squawking (wings out, running) when you rush at them. Place the node in the
## yard (HouseExtras does); the hens stay within `radius` of it, always at one height, and
## stop whenever something is in their way.
##
## Animation is posed in held steps (see Choppy), like the hand-made characters: a four-pose
## waddle with a head bob on every step, a pecking cycle, a two-pose panicked run.

@export var count := 4
@export var radius := 3.0
@export var walk_speed := 0.55
@export var run_speed := 2.6
@export var scare_radius := 2.2
@export var feathers: Array[Color] = [
	Color(0.92, 0.9, 0.84), Color(0.7, 0.4, 0.22), Color(0.82, 0.62, 0.35), Color(0.3, 0.26, 0.24),
]

const GROUND_MASK := 1
const WALK_POSES := 4        ## poses in one waddle cycle
## Neck pitch (radians, negative = head down) for each pose of the pecking cycle.
const PECK_POSES: Array[float] = [0.0, -1.1, -0.1, -1.1, 0.0, 0.0]
const LOOK_POSES: Array[float] = [0.0, 0.0, 0.4, 0.4, -0.35, -0.35, 0.0, 0.0]   ## idle head turns (yaw), held a pose or two

enum State { PECK, WALK, FLEE }

class Hen:
	var rig: Dictionary
	var state := State.PECK
	var timer := 1.0
	var target := Vector3.ZERO
	var offset := 0   ## shifts this hen's cycles so they are not all in step

var _hens: Array[Hen] = []
var _home := Vector3.ZERO
var _base_y := 0.0   ## every hen stays at this height: they never climb or sink
var _last_step := -1

func _ready() -> void:
	_home = global_position
	_base_y = _ground(_home).y
	for i in count:
		var h := Hen.new()
		h.rig = CritterParts.chicken(feathers[i % feathers.size()])
		h.offset = randi() % 8
		h.timer = randf_range(0.5, 3.0)
		var root: Node3D = h.rig["root"]
		add_child(root)
		var a := randf() * TAU
		root.global_position = _level(_home + Vector3(cos(a), 0, sin(a)) * radius * sqrt(randf()))
		root.rotation.y = randf() * TAU
		_hens.append(h)
	_pose_all()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var awake := WorldClock.day_amount() > 0.2   # roosting at night
	for h in _hens:
		var root: Node3D = h.rig["root"]
		root.visible = awake
		if not awake:
			continue
		if player != null and h.state != State.FLEE and player.global_position.distance_to(root.global_position) < scare_radius:
			_scatter(h, player.global_position)
		match h.state:
			State.PECK:
				_peck_logic(h, delta)
			State.WALK:
				_walk(h, delta, walk_speed)
			State.FLEE:
				_walk(h, delta, run_speed)
	var step := Choppy.index()
	if step != _last_step:   # a new pose: hold it until the next step
		_last_step = step
		_pose_all()

# --- behaviour (smooth) --------------------------------------------------

func _peck_logic(h: Hen, delta: float) -> void:
	h.timer -= delta
	if h.timer > 0.0:
		return
	h.timer = randf_range(2.0, 5.0)
	var spot := _spot_near_home(_pos(h))
	if spot != _pos(h):
		h.target = spot
		h.state = State.WALK

func _pos(h: Hen) -> Vector3:
	return (h.rig["root"] as Node3D).global_position

func _walk(h: Hen, delta: float, speed: float) -> void:
	var root: Node3D = h.rig["root"]
	var to := h.target - root.global_position
	to.y = 0.0
	if to.length() < speed * delta + 0.05:
		_stop(h, 2.0, 5.0)
		return
	var dir := to.normalized()
	var here := root.global_position
	if not _path_clear(here, here + dir * (speed * delta + 0.3)):
		_stop(h, 1.5, 3.5)   # something is in the way: just stop
		return
	root.global_position = _level(here + dir * speed * delta)
	# the hens are children of a rotated node, so turn them in world space
	root.global_rotation.y = lerp_angle(root.global_rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)

func _stop(h: Hen, min_time: float, max_time: float) -> void:
	h.state = State.PECK
	h.timer = randf_range(min_time, max_time)

func _scatter(h: Hen, from: Vector3) -> void:
	var away := _pos(h) - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	var spot := _pos(h) + away * randf_range(2.0, 3.5)
	if spot.distance_to(_home) > radius * 1.6:   # don't run out of the yard
		spot = _home + (spot - _home).normalized() * radius * 1.4
	h.target = spot
	h.state = State.FLEE

# --- posing (held steps) -----------------------------------------------------

func _pose_all() -> void:
	var step := Choppy.index()
	for h in _hens:
		_pose(h, step + h.offset)

func _pose(h: Hen, step: int) -> void:
	var neck: Node3D = h.rig["neck"]
	var body: Node3D = h.rig["body"]
	var left_leg: Node3D = h.rig["left_leg"]
	var right_leg: Node3D = h.rig["right_leg"]
	var left_wing: Node3D = h.rig["left_wing"]
	var right_wing: Node3D = h.rig["right_wing"]
	match h.state:
		State.PECK:
			neck.rotation = Vector3(PECK_POSES[step % PECK_POSES.size()] if step % 24 < 18 else 0.0, 0.0, 0.0)
			if step % 24 >= 18:   # now and then it lifts its head and looks around instead
				neck.rotation.y = LOOK_POSES[step % LOOK_POSES.size()]
			body.position.y = 0.3
			left_leg.rotation.x = 0.0
			right_leg.rotation.x = 0.0
			_wings(left_wing, right_wing, 0.0)
		State.WALK:
			var beat := step % WALK_POSES
			var swing := 0.55 if beat < WALK_POSES / 2 else -0.55   # two poses with the left leg forward, two with the right
			left_leg.rotation.x = swing
			right_leg.rotation.x = -swing
			neck.rotation = Vector3(-0.25 if step % 2 == 0 else 0.15, 0.0, 0.0)   # the head thrusts forward on every step
			body.position.y = 0.3 + (0.02 if step % 2 == 0 else 0.0)
			_wings(left_wing, right_wing, 0.05)
		State.FLEE:
			var swing_run := 0.8 if step % 2 == 0 else -0.8                       # a frantic two-pose scramble
			left_leg.rotation.x = swing_run
			right_leg.rotation.x = -swing_run
			neck.rotation = Vector3(-0.35 if step % 2 == 0 else 0.1, 0.0, 0.0)
			body.position.y = 0.3 + (0.04 if step % 2 == 0 else 0.0)
			_wings(left_wing, right_wing, 0.9 if step % 2 == 0 else 0.45)           # wings beating out

func _wings(left_wing: Node3D, right_wing: Node3D, amount: float) -> void:
	right_wing.rotation.z = -amount
	left_wing.rotation.z = amount

# --- ground ------------------------------------------------------------------

func _spot_near_home(from: Vector3) -> Vector3:
	for i in 6:
		var a := randf() * TAU
		var spot := _home + Vector3(cos(a), 0, sin(a)) * radius * sqrt(randf())
		spot.y = _base_y
		if _path_clear(from, spot):
			return spot
	return from

func _path_clear(from: Vector3, to: Vector3) -> bool:
	if Engine.is_editor_hint():
		return true
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.5, to + Vector3.UP * 0.5, GROUND_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## `point` at the hens' fixed height.
func _level(point: Vector3) -> Vector3:
	return Vector3(point.x, _base_y, point.z)

func _ground(point: Vector3) -> Vector3:
	if Engine.is_editor_hint():
		return point   # no physics world in the editor: just stand them where they are
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.5, point + Vector3.DOWN * 3.0, GROUND_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return point if hit.is_empty() else hit["position"]
