@tool
class_name KillerFish
extends CharacterBody3D
## An eldritch fish-thing that kills the player outright. It drifts around the water it was
## placed in. The moment the player touches that water at all (wading counts),
## it is marked: after a sliver of warning it darts at them far faster than
## they can swim, and it does not stop. Getting out of the water doesn't save
## you — it leaps out of the pool and chases over land, straight through the
## world (it has no collision at all) until it touches you: instant death.
##
## Place one: drop a node with this script inside a body of water (it finds the
## WaterVolume under it by itself). The body is built in code, so it also
## shows up in the editor viewport — but nothing is saved into the scene.
## Tuning is all in the exports.

@export var swim_speed := 3.5            ## idle drifting speed
@export var chase_speed := 24.0          ## "extremely fast"
@export var windup := 0.4                ## seconds between spotting you and the dart — a sliver of warning
@export var kill_radius := 1.0           ## touching distance (to the player's centre)
@export var wander_radius := 6.0         ## how far from its start it drifts
@export var body_length := 1.8
@export var color := Color(0.26, 0.1, 0.32)   ## the flesh tone of the creature (see EldritchBody)

const SURFACE_MARGIN := 0.6              ## keeps its body this far under the surface
const TURN_RATE := 14.0
const KILL_DAMAGE := 1.0e9
const RESPAWN_DELAY := 4.0               ## after a kill it vanishes, then reappears at its home spot
const LEAP_ARC := 2.5                    ## how high it bounds when it clears the water
const PREVIEW_GROUP_NAME := "KillerFishBody"

enum Mode { WANDER, WINDUP, CHASE }

var _mode := Mode.WANDER
var _home := Vector3.ZERO
var _dest := Vector3.ZERO
var _water: WaterVolume
var _player: Player
var _windup_t := 0.0
var _wait := 0.0
var _age := 0.0
var _respawn_t := 0.0
var _body: EldritchBody

func _ready() -> void:
	_build_body()
	if Engine.is_editor_hint():
		return
	collision_layer = 0   # no collision with anything: it passes through the world
	collision_mask = 0
	_home = global_position
	_dest = _home

# ---------------------------------------------------------------- the look

## The eldritch look (EldritchBody) lying along the swim direction (-Z). Built
## every time (editor included) and never given an owner, so it isn't saved
## into the scene.
func _build_body() -> void:
	if _body != null:
		return
	_body = EldritchBody.create(body_length, color)
	_body.name = PREVIEW_GROUP_NAME
	add_child(_body)

# ---------------------------------------------------------------- behaviour

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_age += delta
	if _respawn_t > 0.0:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			visible = true
			_body.position.y = 0.0
		return
	if _water == null:
		_water = _find_water()
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null or _water == null:
		return
	if _player.dead:   # a fresh start: forget the grudge
		_mode = Mode.WANDER
		_dest = _home
	match _mode:
		Mode.WANDER:
			_wander(delta)
			if _player.current_water() == _water:   # touched the water, however briefly
				_mode = Mode.WINDUP
				_windup_t = windup
				Telegraph.exclaim(self, 1.0)
		Mode.WINDUP:
			_face_player(delta)
			velocity = Vector3.ZERO
			_windup_t -= delta
			if _windup_t <= 0.0:
				_mode = Mode.CHASE
		Mode.CHASE:
			_chase(delta)
	_wiggle()

func _dist_to_player() -> float:
	return global_position.distance_to(_chest())

func _chest() -> Vector3:
	return _player.global_position + Vector3.UP * (Player.STAND_HEIGHT * 0.5)

func _face_player(delta: float) -> void:
	_turn_toward((_chest() - global_position).normalized(), delta)

func _chase(delta: float) -> void:
	var to := _chest() - global_position
	var dist := to.length()
	if dist <= kill_radius:
		_kill()
		return
	var dir := to / maxf(dist, 0.001)
	_turn_toward(dir, delta)
	# Never overshoot the player in a single step.
	velocity = dir * minf(chase_speed, dist / maxf(delta, 0.0001))
	global_position += velocity * delta   # straight through anything: no water limit, no collision
	# Out of the pool it bounds along in an arc instead of sliding flat.
	if not _water.covers_xz(global_position) or global_position.y > _water.surface_world_y() - SURFACE_MARGIN:
		_body.position.y = absf(sin(_age * 9.0)) * LEAP_ARC * 0.3
	else:
		_body.position.y = 0.0
	if _dist_to_player() <= kill_radius:
		_kill()

func _kill() -> void:
	_player.hit(KILL_DAMAGE, true, global_position)
	_mode = Mode.WANDER
	global_position = _home
	_dest = _home
	velocity = Vector3.ZERO
	visible = false
	_respawn_t = RESPAWN_DELAY

func _wander(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
		_swim(delta)
		return
	var to := _dest - global_position
	if to.length() < 0.7:
		_wait = randf_range(0.3, 1.2)
		_dest = _pick_dest()
		return
	var dir := to.normalized()
	_turn_toward(dir, delta)
	velocity = dir * swim_speed
	_swim(delta)

func _pick_dest() -> Vector3:
	for _i in 8:
		var a := randf() * TAU
		var r := randf_range(1.0, wander_radius)
		var p := _home + Vector3(cos(a) * r, randf_range(-1.5, 1.5), sin(a) * r)
		if _inside_water(p):
			return p
	return _home

## Moves with `velocity` but never out of the water: a step that would leave
## the pool (sideways past its edge, up through the surface) is trimmed.
func _swim(delta: float) -> void:
	var step := velocity * delta
	if not _inside_water(global_position + step):
		var flat := Vector3(step.x, 0.0, step.z)
		if _inside_water(global_position + flat):
			velocity.y = 0.0
		elif _inside_water(global_position + Vector3(0.0, step.y, 0.0)):
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			velocity = Vector3.ZERO
	global_position += velocity * delta

func _inside_water(pos: Vector3) -> bool:
	return _water.covers_xz(pos) and pos.y + SURFACE_MARGIN <= _water.surface_world_y()

func _find_water() -> WaterVolume:
	for w in WaterVolume.active:
		if w.covers_xz(global_position):
			return w
	return null

func _turn_toward(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var up := Vector3.RIGHT if absf(dir.y) > 0.99 else Vector3.UP
	var target := Transform3D().looking_at(dir, up).basis.get_rotation_quaternion()
	var current := global_transform.basis.get_rotation_quaternion()
	global_transform.basis = Basis(current.slerp(target, minf(1.0, TURN_RATE * delta)))

## Tentacles and eye follow the mood: calm while drifting, frantic once hunting.
func _wiggle() -> void:
	if _body == null:
		return
	match _mode:
		Mode.CHASE: _body.set_agitation(1.0)
		Mode.WINDUP: _body.set_agitation(0.6)
		_: _body.set_agitation(0.0)
