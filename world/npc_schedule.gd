class_name NpcSchedule
extends Node
## Gives an NPC a daily routine. Add as a CHILD of an NPC and list `stops` (ScheduleStop:
## from this hour, stand / wander / go indoors at this place); the NPC follows WorldClock —
## strolling to its next place when the hour comes, wandering about its yard, heading home
## at dusk and stepping out again in the morning.
##
## Moving is deliberately simple: straight lines, snapped to the ground, so choose places
## with a clear path between them (a door's front, the yard around it). An NPC never moves
## while you are talking to it or standing next to it — it just turns to look at you.
## When a level (re)loads, everyone is placed straight at the spot their routine says,
## so entering a house and coming back never replays the walk.
##
## quest_flag / quest_done_flag keep a quest giver reachable: while quest_flag is set and
## quest_done_flag is not, INSIDE entries are ignored and the NPC stays out.

@export var stops: Array[ScheduleStop] = []
@export var walk_speed := 1.5
@export var wander_speed := 0.9
@export var turn_speed := 6.0
@export_range(1.0, 8.0) var notice_radius := 3.0     ## stops walking and watches the player inside this
@export var quest_flag: StringName = &""
@export var quest_done_flag: StringName = &""

const GROUND_MASK := 1
const BOB_HEIGHT := 0.05
const BOB_RATE := 9.0

enum State { IDLE, WALKING, HIDDEN }

var _npc: NPC
var _state := State.IDLE
var _home := Vector3.ZERO
var _home_yaw := 0.0
var _stop: ScheduleStop
var _anchor := Vector3.ZERO      ## where the current stop is (wander centre / stand spot)
var _anchor_yaw := 0.0
var _target := Vector3.ZERO
var _hide_on_arrival := false
var _wait := 0.0
var _glance := 0.0
var _glance_yaw := 0.0
var _visual: Node3D
var _visual_rest := Vector3.ZERO
var _bob := 0.0
var _anchor_facing := false      ## has arrived at a STAND spot: settle into its facing

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps running while its NPC is switched off indoors
	_npc = get_parent() as NPC
	if _npc == null or Engine.is_editor_hint() or stops.is_empty():
		set_process(false)
		return
	stops.sort_custom(func(a: ScheduleStop, b: ScheduleStop) -> bool: return a.from_hour < b.from_hour)
	_home = _npc.global_position
	_home_yaw = _npc.rotation.y
	_visual = _npc.get_visual()
	if _visual != null:
		_visual_rest = _visual.position
	WorldClock.hour_changed.connect(_on_hour_changed)
	Events.story_flag_changed.connect(func(_f, _v) -> void: _refresh(false))
	_refresh.call_deferred(true)

func _on_hour_changed(_hour: int) -> void:
	_refresh(false)

# --- which stop is current -----------------------------------------------

func _current_stop() -> ScheduleStop:
	var stay_out := quest_flag != &"" and Game.flag(quest_flag) and not (quest_done_flag != &"" and Game.flag(quest_done_flag))
	var current: ScheduleStop = stops.back()   # before the first entry: still doing last night's
	var h := WorldClock.hour
	for s in stops:
		if stay_out and s.mode == ScheduleStop.Mode.INSIDE:
			continue
		if s.from_hour <= h:
			current = s
	if stay_out and current.mode == ScheduleStop.Mode.INSIDE:
		for s in stops:   # no earlier outdoor entry today: use the last outdoor one overall
			if s.mode != ScheduleStop.Mode.INSIDE:
				current = s
	return current

func _refresh(snap: bool) -> void:
	var next := _current_stop()
	if next == _stop and not snap:
		return
	_stop = next
	_resolve_anchor()
	if snap:
		_snap_to_stop()
	elif _stop.mode == ScheduleStop.Mode.INSIDE:
		if _state != State.HIDDEN:   # (already indoors: nothing to do)
			_walk_to(_anchor, true)
	else:
		if _state == State.HIDDEN:
			_emerge(_door_position())
		_walk_to(_pick_stand_point(), false)

func _resolve_anchor() -> void:
	_anchor = _home
	_anchor_yaw = _home_yaw
	if _stop.place.is_empty():
		return
	var node := _lookup(_stop.place)
	if node != null:
		_anchor = node.global_position
		_anchor_yaw = node.global_rotation.y

func _lookup(path: NodePath) -> Node3D:
	var root: Node = owner if owner != null else get_tree().current_scene
	var node := root.get_node_or_null(path) as Node3D if root != null else null
	return node if node != null else get_node_or_null(path) as Node3D

## The nearest door-type stop (an INSIDE entry's place): where indoors NPCs appear.
func _door_position() -> Vector3:
	for s in stops:
		if s.mode == ScheduleStop.Mode.INSIDE and not s.place.is_empty():
			var n := _lookup(s.place)
			if n != null:
				return n.global_position
	return _home

func _snap_to_stop() -> void:
	if _stop.mode == ScheduleStop.Mode.INSIDE:
		_go_inside()
		return
	_state = State.IDLE
	_set_available(true)
	_npc.global_position = _ground(_anchor)
	_npc.rotation.y = _anchor_yaw
	_wait = randf_range(1.0, 4.0)

# --- moving ----------------------------------------------------------------

func _walk_to(point: Vector3, then_hide: bool) -> void:
	_target = point
	_hide_on_arrival = then_hide
	_state = State.WALKING

func _pick_stand_point() -> Vector3:
	if _stop.mode == ScheduleStop.Mode.WANDER:
		return _random_near(_anchor, _stop.wander_radius)
	return _anchor

func _random_near(centre: Vector3, radius: float) -> Vector3:
	for i in 6:
		var a := randf() * TAU
		var candidate := centre + Vector3(cos(a), 0.0, sin(a)) * sqrt(randf()) * radius
		if _clear_path(_npc.global_position, candidate):
			return candidate
	return centre

func _clear_path(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.7, to + Vector3.UP * 0.7, GROUND_MASK, [_npc.get_rid()])
	return _npc.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## `point` dropped onto whatever solid ground is under it (keeps its own height if nothing is).
func _ground(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 4.0, GROUND_MASK, [_npc.get_rid()])
	var hit := _npc.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return point
	return hit["position"]

func _set_available(on: bool) -> void:
	_npc.available = on
	_npc.visible = on
	_npc.collision_layer = 1 if on else 0

func _go_inside() -> void:
	_state = State.HIDDEN
	_set_available(false)

func _emerge(at: Vector3) -> void:
	_set_available(true)
	_npc.global_position = _ground(at)
	_state = State.IDLE

func _process(delta: float) -> void:
	if get_tree().paused or _state == State.HIDDEN:
		return
	var talking := DialogueBox.instance != null and DialogueBox.instance.is_active()
	if talking:
		_apply_bob(0.0, delta)
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var near_player := player != null and player.global_position.distance_to(_npc.global_position) < notice_radius
	if near_player:
		_look_at(player.global_position, delta)
		_apply_bob(0.0, delta)
		return
	match _state:
		State.WALKING:
			_step_walk(delta)
		State.IDLE:
			_step_idle(delta)

func _step_walk(delta: float) -> void:
	var pos := _npc.global_position
	var to := _target - pos
	to.y = 0.0
	var speed := wander_speed if _stop.mode == ScheduleStop.Mode.WANDER and not _hide_on_arrival else walk_speed
	if to.length() <= speed * delta + 0.05:
		_arrive()
		return
	var dir := to.normalized()
	var next := pos + dir * speed * delta
	next = _ground(next)
	_npc.global_position = next
	_turn_to(atan2(-dir.x, -dir.z) + _npc.facing_offset, delta)
	_apply_bob(1.0, delta)

func _arrive() -> void:
	_apply_bob(0.0, 0.0)
	if _hide_on_arrival:
		_go_inside()
		return
	_state = State.IDLE
	_wait = randf_range(2.0, 6.0)
	if _stop.mode == ScheduleStop.Mode.STAND:
		_anchor_facing = true

func _step_idle(delta: float) -> void:
	_apply_bob(0.0, delta)
	if _stop.mode == ScheduleStop.Mode.STAND and _anchor_facing:
		_turn_to(_anchor_yaw, delta)   # settle into the spot's own facing
	_wait -= delta
	if _glance > 0.0:
		_glance -= delta
		_turn_to(_glance_yaw, delta)
		return
	if _wait > 0.0:
		return
	if _stop.mode == ScheduleStop.Mode.WANDER:
		_walk_to(_random_near(_anchor, _stop.wander_radius), false)
	else:
		_glance = randf_range(1.2, 2.4)   # a quick look around, then back
		_glance_yaw = _anchor_yaw + randf_range(-0.9, 0.9)
		_anchor_facing = true
		_wait = randf_range(5.0, 11.0)

func _look_at(world_pos: Vector3, delta: float) -> void:
	var d := world_pos - _npc.global_position
	_turn_to(atan2(-d.x, -d.z) + _npc.facing_offset, delta)

func _turn_to(yaw: float, delta: float) -> void:
	_npc.rotation.y = lerp_angle(_npc.rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))

## A little hop-and-sway while walking, on the model only (the collision stays put).
func _apply_bob(amount: float, delta: float) -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	_bob += delta * BOB_RATE * amount
	var k := clampf(amount, 0.0, 1.0)
	_visual.position = _visual_rest + Vector3(0.0, absf(sin(_bob)) * BOB_HEIGHT * k, 0.0)
	_visual.rotation.z = lerpf(_visual.rotation.z, sin(_bob) * 0.04 * k, 0.4)
