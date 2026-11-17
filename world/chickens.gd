@tool
class_name Chickens
extends Node3D
## A few hens pottering about a yard: they walk to a spot, peck at the ground, wander on,
## and scatter squawking (wings out, running) when you rush at them. Place the node in the
## yard (HouseExtras puts one by a house); the hens stay within `radius` of it and never
## walk through walls (a short ray check) or float (they stick to the ground).

@export var count := 4
@export var radius := 3.0
@export var walk_speed := 0.55
@export var run_speed := 2.6
@export var scare_radius := 2.2
@export var feathers: Array[Color] = [
	Color(0.92, 0.9, 0.84), Color(0.7, 0.4, 0.22), Color(0.82, 0.62, 0.35), Color(0.3, 0.26, 0.24),
]

const GROUND_MASK := 1

enum State { PECK, WALK, FLEE }

class Hen:
	var rig: Dictionary
	var state := State.PECK
	var timer := 1.0
	var target := Vector3.ZERO
	var phase := 0.0

var _hens: Array[Hen] = []
var _home := Vector3.ZERO
var _base_y := 0.0   ## every hen stays at this height: they never climb or sink

func _ready() -> void:
	_home = global_position
	_base_y = _ground(_home).y
	for i in count:
		var h := Hen.new()
		h.rig = CritterParts.chicken(feathers[i % feathers.size()])
		h.phase = randf() * TAU
		h.timer = randf_range(0.5, 3.0)
		var root: Node3D = h.rig["root"]
		add_child(root)
		var a := randf() * TAU
		root.global_position = _level(_home + Vector3(cos(a), 0, sin(a)) * radius * sqrt(randf()))
		root.rotation.y = randf() * TAU
		_hens.append(h)

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
				_peck(h, delta)
			State.WALK:
				_walk(h, delta, walk_speed)
			State.FLEE:
				_walk(h, delta, run_speed)

func _peck(h: Hen, delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# head dips to the ground in quick pecks, then looks up for a moment
	var cycle := fposmod(t * 1.3 + h.phase, 3.0)
	var dip := 0.0
	if cycle < 1.8:
		dip = pow(maxf(sin(cycle * 7.0), 0.0), 2.0) * 1.1
	(h.rig["neck"] as Node3D).rotation.x = dip
	_flap(h, 0.0)
	h.timer -= delta
	if h.timer <= 0.0:
		var spot := _spot_near_home(root_pos(h))
		if spot != root_pos(h):
			h.target = spot
			h.state = State.WALK
		h.timer = randf_range(2.0, 5.0)

func root_pos(h: Hen) -> Vector3:
	return (h.rig["root"] as Node3D).global_position

func _walk(h: Hen, delta: float, speed: float) -> void:
	var root: Node3D = h.rig["root"]
	var to := h.target - root.global_position
	to.y = 0.0
	if to.length() < speed * delta + 0.05:
		h.state = State.PECK
		h.timer = randf_range(2.0, 5.0)
		_flap(h, 0.0)
		return
	var dir := to.normalized()
	var here := root.global_position
	if not _path_clear(here, here + dir * (speed * delta + 0.3)):
		h.state = State.PECK   # something is in the way: just stop
		h.timer = randf_range(1.5, 3.5)
		_flap(h, 0.0)
		return
	root.global_position = _level(here + dir * speed * delta)
	# the hens are children of a rotated node, so turn them in world space
	root.global_rotation.y = lerp_angle(root.global_rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	var t := Time.get_ticks_msec() / 1000.0
	var stride := 9.0 if h.state == State.WALK else 18.0
	(h.rig["neck"] as Node3D).rotation.x = sin(t * stride + h.phase) * 0.12 - 0.05   # head bobs with each step
	(h.rig["body"] as Node3D).rotation.z = sin(t * stride * 0.5 + h.phase) * 0.06
	_flap(h, 1.0 if h.state == State.FLEE else 0.0)

func _scatter(h: Hen, from: Vector3) -> void:
	var away := (root_pos(h) - from)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	var spot := root_pos(h) + away * randf_range(2.0, 3.5)
	if spot.distance_to(_home) > radius * 1.6:   # don't run out of the yard
		spot = _home + (spot - _home).normalized() * radius * 1.4
	h.target = spot
	h.state = State.FLEE
	h.timer = 0.0

func _flap(h: Hen, amount: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var w := amount * (0.7 + sin(t * 35.0) * 0.5)
	(h.rig["right_wing"] as Node3D).rotation.z = -w
	(h.rig["left_wing"] as Node3D).rotation.z = w

func _spot_near_home(from: Vector3) -> Vector3:
	for i in 6:
		var a := randf() * TAU
		var spot := _home + Vector3(cos(a), 0, sin(a)) * radius * sqrt(randf())
		if _path_clear(from, spot):
			return spot
	return from

func _path_clear(from: Vector3, to: Vector3) -> bool:
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
