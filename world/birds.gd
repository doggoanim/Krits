class_name Birds
extends Node3D
## A few songbirds living on the rooftops. They sit on perch points (any node in the
## `bird_perch` group — HouseExtras puts one pair on every roof ridge), look about, hop,
## and now and then flutter to another perch. Walk close and they take off, flying away to
## the perch farthest from you. They sleep (vanish) at night.
##
## Drop one Birds node anywhere in the level; it builds its flock from CritterParts once the
## perches exist. Purely decorative: no collision, no sound (the bird sounds are part of the level's grassland ambience).

@export var bird_count := 7
@export var perch_group := &"bird_perch"
@export var flee_radius := 6.0
@export var fly_speed := 6.5
@export var stay_time := Vector2(8.0, 22.0)   ## seconds a bird sits before wandering off by itself
@export var palette: Array[Color] = [
	Color(0.55, 0.4, 0.28), Color(0.35, 0.5, 0.78), Color(0.72, 0.3, 0.2), Color(0.85, 0.85, 0.82), Color(0.45, 0.45, 0.5),
]

const FLOCK_SFX := "res://sounds/SFX/others/bird_flock.ogg"
const FLOCK_DB := -3.0
const FLOCK_GAP_MSEC := 4000   ## the whole flock bursting up is one sound, not one per bird

enum State { PERCHED, FLYING }

class Flock:
	var rig: Dictionary
	var state := State.PERCHED
	var perch := -1
	var stay := 0.0
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var t := 0.0
	var duration := 1.0
	var arc := 1.0
	var next_perch := -1
	var look := 0.0
	var look_target := 0.0
	var hop := 0.0

var _perches: Array[Vector3] = []
var _taken: Array[bool] = []
var _birds: Array[Flock] = []
var _tries := 0.0
var _built := false
var _last_step := -1
var _flock_sfx: AudioStream
var _next_flock_msec := 0
var _new_step := false   ## true on the frame a new held pose begins (see Choppy)

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)

func _process(delta: float) -> void:
	if not _built:
		_tries += delta
		if _tries > 0.5:
			_tries = 0.0
			_try_build()
		return
	var step := Choppy.index()
	_new_step = step != _last_step
	_last_step = step
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var ppos := player.global_position if player != null else Vector3(INF, INF, INF)
	var awake := WorldClock.day_amount() > 0.2
	for b in _birds:
		if b.state == State.PERCHED:
			_step_perched(b, delta, ppos, awake)
		else:
			_step_flying(b, delta)

func _try_build() -> void:
	for node in get_tree().get_nodes_in_group(perch_group):
		_perches.append((node as Node3D).global_position)
		_taken.append(false)
	if _perches.size() < 2:
		_perches.clear()
		_taken.clear()
		return   # roofs not dressed yet; try again shortly
	_built = true
	var takes := SpatialSfx.load_takes([FLOCK_SFX])
	_flock_sfx = takes[0] if not takes.is_empty() else null
	for i in mini(bird_count, _perches.size() - 1):
		var b := Flock.new()
		var back := palette[i % palette.size()]
		b.rig = CritterParts.bird(back, back.lightened(0.35) if i % 3 != 0 else Color(0.95, 0.55, 0.3))
		var root: Node3D = b.rig["root"]
		add_child(root)
		b.perch = _free_perch()
		_taken[b.perch] = true
		root.global_position = _perches[b.perch]
		root.rotation.y = randf() * TAU
		b.stay = randf_range(stay_time.x, stay_time.y)
		_fold(b)
		_birds.append(b)

func _free_perch(avoid := Vector3(INF, INF, INF)) -> int:
	var best := -1
	var best_d := -1.0
	var options: Array[int] = []
	for i in _perches.size():
		if not _taken[i]:
			options.append(i)
	if options.is_empty():
		return -1
	if avoid.x == INF:
		return options[randi() % options.size()]
	for i in options:
		var d := _perches[i].distance_to(avoid) + randf() * 3.0
		if d > best_d:
			best_d = d
			best = i
	return best

func _step_perched(b: Flock, delta: float, ppos: Vector3, awake: bool) -> void:
	var root: Node3D = b.rig["root"]
	root.visible = awake
	if not awake:
		return
	if ppos.distance_to(root.global_position) < flee_radius:
		_take_off(b, ppos)
		return
	b.stay -= delta
	if b.stay <= 0.0:
		_take_off(b, Vector3(INF, INF, INF))
		return
	# idle: look around, bob the tail, now and then a hop
	var head: Node3D = b.rig["head"]
	b.look = lerpf(b.look, b.look_target, 6.0 * delta)
	if _new_step:
		head.rotation.y = b.look
	if randf() < 0.6 * delta:
		b.look_target = randf_range(-1.0, 1.0)
	if randf() < 0.12 * delta:
		b.hop = 1.0
	b.hop = maxf(b.hop - 5.0 * delta, 0.0)
	if _new_step:   # hops and tail bobs are held poses
		root.global_position.y = _perches[b.perch].y + sin(b.hop * PI) * 0.05
		var tail: Node3D = b.rig["tail"]
		tail.rotation.x = deg_to_rad(-14.0) + (0.08 if (Choppy.index() / 6 + b.perch) % 2 == 0 else -0.08)

func _take_off(b: Flock, scared_of: Vector3) -> void:
	var dest := _free_perch(scared_of)
	if dest < 0:
		b.stay = randf_range(stay_time.x, stay_time.y)
		return
	if scared_of.x != INF:   # startled by the player (not just wandering to another perch)
		_flock_startled((b.rig["root"] as Node3D).global_position)
	_taken[b.perch] = false
	_taken[dest] = true
	b.next_perch = dest
	b.state = State.FLYING
	var root: Node3D = b.rig["root"]
	b.from = root.global_position
	b.to = _perches[dest]
	b.t = 0.0
	var dist := b.from.distance_to(b.to)
	b.duration = maxf(dist / fly_speed, 0.6)
	b.arc = clampf(dist * 0.18, 0.6, 3.0)
	(b.rig["head"] as Node3D).rotation.y = 0.0

## The flock bursts up at the sound of footsteps: one wing-clatter, from where the first bird left.
func _flock_startled(at: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if _flock_sfx == null or now < _next_flock_msec:
		return
	_next_flock_msec = now + FLOCK_GAP_MSEC
	SpatialSfx.play(self, _flock_sfx, at, FLOCK_DB, Vector2(0.95, 1.05), 40.0, 8.0)

func _step_flying(b: Flock, delta: float) -> void:
	var root: Node3D = b.rig["root"]
	var prev := root.global_position
	b.t = minf(b.t + delta / b.duration, 1.0)
	var pos := b.from.lerp(b.to, b.t)
	pos.y += sin(b.t * PI) * b.arc
	root.global_position = pos
	var dir := pos - prev
	dir.y = 0.0
	if dir.length() > 0.001:
		root.rotation.y = lerp_angle(root.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	if _new_step:   # wings snap between an up and a down pose each step
		var flap := 0.95 if Choppy.index() % 2 == 0 else -0.6
		(b.rig["right_wing"] as Node3D).rotation.z = flap
		(b.rig["left_wing"] as Node3D).rotation.z = -flap
	if b.t >= 1.0:
		b.perch = b.next_perch
		b.state = State.PERCHED
		b.stay = randf_range(stay_time.x, stay_time.y)
		root.rotation.y = randf() * TAU
		_fold(b)

func _fold(b: Flock) -> void:
	(b.rig["right_wing"] as Node3D).rotation.z = 0.12
	(b.rig["left_wing"] as Node3D).rotation.z = -0.12
