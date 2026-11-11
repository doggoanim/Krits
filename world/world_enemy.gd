class_name WorldEnemy
extends CharacterBody3D
## Overworld enemy. Invisible until the player comes close, then pops in and
## wanders around its home. When the player comes within detect range it
## notices them ("!"), then chases until they get away (see EnemyData's Chase
## group) and walks back home. Touching it emits `touched` (EncounterManager
## takes over).

signal touched(enemy: WorldEnemy)

@export var enemy_id: StringName = &""        ## unique id; defeated ids are saved as cleared
@export var data: EnemyData                     ## leave empty to use `type` below
@export_enum("Green Slime", "Spinner", "Piercer", "Fish") var type := 0   ## pick the enemy right in the Inspector
@export var spawn_radius := 22.0
@export var despawn_radius := 32.0
@export var wander_radius := 8.0
@export var gravity := 30.0
@export var respawn_time := 10.0   ## seconds until it comes back — only for enemies with an EMPTY enemy_id (ids are saved as cleared for good)

## Set by the encounter sequence. Also hides this actor for the duration: the
## fight itself plays out nearby using a freshly-spawned Enemy inside the
## Arena, so this original would otherwise just stand there frozen in plain
## sight next to (or far from) the real fight, looking like a stray duplicate.
var _dead := false          ## defeated, waiting to respawn (empty enemy_id only)

enum Mode { WANDER, ALERT, CHASE, RETURN }   ## RETURN = walking back home after giving up

const BLOCKED_GIVE_UP := 0.7    ## seconds pressed against a wall (not getting anywhere) before a chaser drops the chase
const BLOCKED_PROGRESS := 0.35  ## fraction of the intended speed it must actually achieve to count as moving
const LOSE_RANGE_MULT := 1.4     ## farther than detect_radius * this counts as "out of range" for lose_time
const HOME_ARRIVE_DIST := 1.0
const CHASE_LEAD_MAX := 0.6      ## seconds of the player's motion a chaser aims ahead by
const LEDGE_PROBE_DEPTH := 4.0   ## no ground within this far below the next step = a drop, so don't step
const WATER_STOP_DEPTH := 0.6    ## a land enemy won't step into water deeper than this (it stops at the edge)
const WATER_AGGRO_COOLDOWN := 3.0   ## after giving up at the water's edge it ignores the player this long, so it doesn't re-notice and re-chase at once
const FISH_SURFACE_MARGIN := 0.6    ## a fish keeps its body this far below the waterline
const FISH_WANDER_HEIGHT := 1.5     ## wandering fish drift this far above/below their home depth
const SWIM_DRAG := 8.0              ## how fast a fish stops when it has nowhere to go

var frozen := false:
	set(value):
		frozen = value
		if value:
			_mode = Mode.WANDER   # a fight starts: whoever was chasing goes back to idling
		if _visual:
			_visual.visible = _awake and not value

var _mode := Mode.WANDER
var _blocked_t := 0.0   ## how long the current chase has been stuck against a wall
var _mode_t := 0.0           ## ALERT: time left on the "!"; CHASE: time spent unable to see the player
var _recover_t := 0.0        ## after hurting an unarmed player: stands off until this runs out
var _chase_t := 0.0          ## seconds spent chasing without losing the player (drives the speed ramp)
var _awake := false
var _aggro_cd := 0.0         ## >0 right after giving up at the water's edge: no noticing yet
var _water: WaterVolume      ## aquatic only: the body of water this fish lives in (found lazily)
var _solid := false          ## true once the pop-in finished; only then can it be touched
var _home := Vector3.ZERO
var _dest := Vector3.ZERO
var _wait := 0.0
var _visual: Node3D         ## pop-in/sleep wrapper (scaled 0..1 by _wake/_sleep)
var _model_visual: EnemyVisual   ## set only when data.model is used, for idle/move animation
var _contact: Area3D
var _player: Player
var _tween: Tween

func _ready() -> void:
	if data == null:
		data = [EnemyLibrary.green_slime, EnemyLibrary.spinner, EnemyLibrary.piercer, EnemyLibrary.fish][type].call()
	if enemy_id != &"" and Game.flag(_cleared_key(), false):
		queue_free()
		return
	add_to_group(&"world_enemies")
	collision_layer = 1 << 2   # layer 3: enemy
	collision_mask = 1
	if data.aquatic:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING   # no floor, no gravity: it swims
	_home = global_position
	_dest = _home

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.7 * data.size
	cs.shape = sh
	cs.position.y = 0.7 * data.size
	add_child(cs)

	_visual = Node3D.new()
	add_child(_visual)
	if data.model:
		_model_visual = EnemyVisual.new()
		_visual.add_child(_model_visual)
		_model_visual.setup(data)
	else:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.7 * data.size
		sm.height = 1.4 * data.size
		mi.mesh = sm
		mi.position.y = 0.7 * data.size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = data.color
		mat.emission_enabled = true
		mat.emission = data.color
		mat.emission_energy_multiplier = 0.4
		# Cel-shaded to match the character: hard light/shadow bands, no shiny highlight.
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mi.material_override = mat
		_visual.add_child(mi)

	_contact = Area3D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 1 << 1
	var cc := CollisionShape3D.new()
	var cshape := SphereShape3D.new()
	cshape.radius = 1.2 * data.size
	cc.shape = cshape
	cc.position.y = 0.7 * data.size
	_contact.add_child(cc)
	add_child(_contact)
	_set_dormant_visuals()

func is_awake() -> bool:
	return _awake

## The player touched us with no weapon to fight with: hurt them (they're
## knocked back and get the usual brief invincibility), then stand off for a
## moment so one touch can't chain into a stunlock.
func strike_player(p: Player) -> void:
	if _recover_t > 0.0:
		return
	_recover_t = data.contact_recover
	velocity.x = 0.0
	velocity.z = 0.0
	p.hit(data.contact_damage, false, global_position)

## Called when the player wins: persist and remove.
func defeat() -> void:
	if enemy_id != &"":
		Game.set_flag(_cleared_key(), true)
		queue_free()
		return
	_respawn_later()

## No id = no save flag, so rather than vanishing for good it goes dormant at
## its home and comes back after `respawn_time` (the timer pauses with the game).
func _respawn_later() -> void:
	_dead = true
	_mode = Mode.WANDER
	_awake = false
	_solid = false
	_kill_tween()
	collision_layer = 0
	global_position = _home
	velocity = Vector3.ZERO
	_dest = _home
	_set_dormant_visuals()
	await get_tree().create_timer(respawn_time, false).timeout
	collision_layer = 1 << 2
	_dead = false

func _cleared_key() -> StringName:
	return StringName("cleared_" + str(enemy_id))

func _physics_process(delta: float) -> void:
	if frozen or _dead:
		return
	_recover_t = maxf(0.0, _recover_t - delta)
	_aggro_cd = maxf(0.0, _aggro_cd - delta)
	if data.aquatic and _water == null:
		_water = WaterVolume.over(global_position)   # the pool it was placed in
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if not _awake and dist <= spawn_radius:
		_wake()
	elif _awake and dist > despawn_radius:
		_sleep()
	if not _awake:
		return
	match _mode:
		Mode.WANDER:
			_wander(delta)
			_try_notice(dist)
		Mode.ALERT:
			_alert(delta, to_player)
		Mode.CHASE:
			_chase(delta, to_player, dist)
		Mode.RETURN:
			_return_home(delta)
			_try_notice(dist)
	if _solid and not _player.dead and _recover_t <= 0.0:
		for b in _contact.get_overlapping_bodies():
			if b == _player:
				touched.emit(self)
				break

# --- Chase ---------------------------------------------------------------------

func _try_notice(dist: float) -> void:
	if not _can_notice(dist):
		return
	_alert_up()
	# Idle friends nearby join in, so passing a camp wakes the whole camp.
	if data.chain_alert_radius > 0.0:
		for n in get_tree().get_nodes_in_group(&"world_enemies"):
			var other := n as WorldEnemy
			if other != self and other._awake and other._mode in [Mode.WANDER, Mode.RETURN] \
					and other.global_position.distance_to(global_position) <= data.chain_alert_radius:
				other._alert_up()

## Awake, idle, close enough and able to see the player. (Armed or not: an
## unarmed player isn't fought, just hurt on contact — see strike_player().)
func _can_notice(dist: float) -> bool:
	if not data.chase_enabled or not _solid or _player.dead or Game.in_combat or Game.input_locked:
		return false
	if _aggro_cd > 0.0 or not _same_medium():
		return false
	if dist > data.detect_radius or _out_of_reach():
		return false
	return not data.line_of_sight or _can_see_player()

## The player is on a ledge higher than this enemy can get to, or far below it.
func _out_of_reach() -> bool:
	if data.aquatic:
		return false   # swimmers share the pool in 3D: depth is no obstacle
	var dy := _player.global_position.y - global_position.y
	return dy > data.max_climb or dy < -8.0

func _alert_up() -> void:
	if _mode == Mode.ALERT or _mode == Mode.CHASE or not data.chase_enabled or not _solid:
		return
	_mode = Mode.ALERT
	_mode_t = data.alert_time
	velocity.x = 0.0
	velocity.z = 0.0
	if _model_visual:
		_model_visual.play_idle()
	Telegraph.exclaim(self, Enemy.body_height(data) + 0.5)

## Stands still on its "!", turned toward the player, then runs.
func _alert(delta: float, to_player: Vector3) -> void:
	if to_player.length() > 0.01:
		var dir := to_player.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 10.0 * delta))
	_apply_gravity(delta)
	_mode_t -= delta
	if _mode_t <= 0.0:
		_mode = Mode.CHASE
		_mode_t = 0.0
		_chase_t = 0.0

func _chase(delta: float, to_player: Vector3, dist: float) -> void:
	if _recover_t > 0.0:   # just hit the player: catches its breath instead of crowding them
		velocity.x = 0.0
		velocity.z = 0.0
		if _model_visual:
			_model_visual.play_idle()
		_apply_gravity(delta)
		move_and_slide()
		return
	var too_far_from_home := global_position.distance_to(_home) > data.leash_radius
	if _player.dead or Game.in_combat or too_far_from_home or dist > data.give_up_radius or not _same_medium():
		_give_up()   # (also when the player dives in / climbs out: it can't follow into the other medium)
		return
	# Out of range or out of sight for a while = lost them.
	var lost := dist > data.detect_radius * LOSE_RANGE_MULT \
			or (data.line_of_sight and not _can_see_player()) or _out_of_reach()
	_mode_t = _mode_t + delta if lost else 0.0
	_chase_t = 0.0 if lost else _chase_t + delta
	if _mode_t >= data.lose_time:
		_give_up()
		return
	# Persistence pays off: it speeds up the longer it keeps you in sight.
	var speed := data.chase_speed * (1.0 + data.chase_ramp * clampf(_chase_t / maxf(data.chase_ramp_time, 0.01), 0.0, 1.0))
	# Head for where the player is going, not where they were: a dash or a long
	# jump would otherwise leave it running at an empty spot.
	var lead := _player.get_hvel() * minf(dist / maxf(speed, 0.1), CHASE_LEAD_MAX)
	if data.aquatic:
		_chase_swim(speed, delta)
		return
	var aim := to_player + lead
	aim.y = 0.0
	if aim.length() > 0.01:
		if _water_ahead(aim.normalized()):
			_give_up_at_water()   # the player went into the water: this is as far as it goes
			return
		_move_toward(aim.normalized(), speed, delta)
		_track_blocked(speed, delta)

## A chaser jammed against a wall (the player is behind it, or above a ledge it
## can't climb) gives up instead of pushing at it forever.
func _track_blocked(speed: float, delta: float) -> void:
	var achieved := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if is_on_wall() and achieved < speed * BLOCKED_PROGRESS:
		_blocked_t += delta
		if _blocked_t >= BLOCKED_GIVE_UP:
			_give_up()
	else:
		_blocked_t = 0.0

func _give_up_at_water() -> void:
	_aggro_cd = WATER_AGGRO_COOLDOWN
	_give_up()

func _give_up() -> void:
	_blocked_t = 0.0
	_mode = Mode.RETURN
	_mode_t = 0.0

func _return_home(delta: float) -> void:
	if data.aquatic:
		var back := _home - global_position
		if back.length() < HOME_ARRIVE_DIST:
			_mode = Mode.WANDER
			_dest = _home
			_wait = 0.5
			return
		_swim_toward(back.normalized(), data.move_speed, delta)
		return
	var flat := _home - global_position
	flat.y = 0.0
	if flat.length() < HOME_ARRIVE_DIST:
		_mode = Mode.WANDER
		_dest = _home
		_wait = 0.5
		return
	_move_toward(flat.normalized(), data.move_speed, delta)

## Walks along `dir` at `speed`, turning to face it; stops at the edge of a drop.
func _move_toward(dir: Vector3, speed: float, delta: float) -> void:
	if _ground_ahead(dir) and not _water_ahead(dir):
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if _model_visual:
			_model_visual.play_move()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _model_visual:
			_model_visual.play_idle()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 10.0 * delta))
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if data.aquatic:
		velocity.y = move_toward(velocity.y, 0.0, SWIM_DRAG * delta)
		return
	velocity.y = -1.0 if is_on_floor() else velocity.y - gravity * delta

## Is there floor a step ahead? (so a chaser doesn't run off a cliff)
func _ground_ahead(dir: Vector3) -> bool:
	var from := global_position + dir * (0.9 * data.size) + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * LEDGE_PROBE_DEPTH, 1)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Clear line from this enemy's eyes to the player's chest (world geometry only).
func _can_see_player() -> bool:
	var from := global_position + Vector3.UP * (0.8 * data.size)
	var to := _player.global_position + Vector3.UP * (Player.STAND_HEIGHT * 0.6)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _wander(delta: float) -> void:
	if data.aquatic:
		_wander_swim(delta)
		return
	var flat := _dest - global_position
	flat.y = 0.0
	if _wait > 0.0:
		_wait -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _model_visual:
			_model_visual.play_idle()
	elif flat.length() < 0.5:
		_wait = randf_range(0.6, 2.0)
		var a := randf() * TAU
		_dest = _home + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.0, wander_radius)
		if _model_visual:
			_model_visual.play_idle()
	else:
		var dir := flat.normalized()
		if _water_ahead(dir):
			_dest = _home   # don't wander into the water: turn back
			_wait = 0.8
			return
		velocity.x = dir.x * data.move_speed * 0.6
		velocity.z = dir.z * data.move_speed * 0.6
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 8.0 * delta))
		if _model_visual:
			_model_visual.play_move()
	velocity.y = -1.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()

func _wake() -> void:
	_awake = true
	_visual.visible = true
	_contact.monitoring = true
	_kill_tween()
	_visual.scale = Vector3.ZERO
	VFX.smoke_puff(self, global_position + Vector3.UP * (0.7 * data.size), data.size)
	_tween = create_tween()
	# Quick pop with a snappy overshoot — much shorter than before, the same
	# TRANS_BACK/EASE_OUT curve just lands fast instead of drifting in.
	_tween.tween_property(_visual, "scale", Vector3.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _solid = true)

func _sleep() -> void:
	_mode = Mode.WANDER
	_awake = false
	_solid = false
	_contact.monitoring = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_visual, "scale", Vector3.ZERO, 0.3)
	_tween.tween_callback(func():
		global_position = _home
		velocity = Vector3.ZERO
		_dest = _home
		_set_dormant_visuals())

func _set_dormant_visuals() -> void:
	_visual.visible = false
	_visual.scale = Vector3.ZERO
	_contact.monitoring = false

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

# --- Water rules --------------------------------------------------------------

## True if this enemy and the player are in the same medium: fish with a
## swimming player, land enemies with anyone who isn't swimming.
func _same_medium() -> bool:
	return data.aquatic == UnderwaterRules.is_swimming(_player)

## Would the next step take a land enemy into water deeper than WATER_STOP_DEPTH?
func _water_ahead(dir: Vector3) -> bool:
	var p := global_position + dir * (0.9 * data.size + 0.4)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP, p + Vector3.DOWN * LEDGE_PROBE_DEPTH, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var ground: Vector3 = hit.position
	var vol := WaterVolume.at(ground)
	return vol != null and vol.surface_world_y() - ground.y > WATER_STOP_DEPTH

# --- Swimming (aquatic enemies) --------------------------------------------------

## Drifts around its home depth in the pool, pausing now and then.
func _wander_swim(delta: float) -> void:
	var to_dest := _dest - global_position
	if _wait > 0.0:
		_wait -= delta
		velocity = velocity.move_toward(Vector3.ZERO, SWIM_DRAG * delta)
		if _model_visual:
			_model_visual.play_idle()
		_move_in_water(delta)
	elif to_dest.length() < 0.6:
		_wait = randf_range(0.3, 1.2)
		_dest = _pick_swim_dest()
	else:
		_swim_toward(to_dest.normalized(), data.move_speed * 0.6, delta)

func _pick_swim_dest() -> Vector3:
	for _i in 8:
		var a := randf() * TAU
		var r := randf_range(1.0, wander_radius)
		var p := _home + Vector3(cos(a) * r, randf_range(-FISH_WANDER_HEIGHT, FISH_WANDER_HEIGHT), sin(a) * r)
		if _inside_water(p):
			return p
	return _home

## Chases the player in 3D, leading their motion a little like a land chaser does.
func _chase_swim(speed: float, delta: float) -> void:
	var chest := _player.global_position + Vector3.UP * (Player.STAND_HEIGHT * 0.5)
	var body := global_position + Vector3.UP * (0.7 * data.size)
	var lead := _player.velocity * 0.25
	var aim := chest + lead - body
	if aim.length() > 0.1:
		_swim_toward(aim.normalized(), speed, delta)
		_track_blocked(speed, delta)

func _swim_toward(dir: Vector3, speed: float, delta: float) -> void:
	velocity = dir * speed
	if _model_visual:
		_model_visual.play_move()
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, 10.0 * delta))
	_move_in_water(delta)

## Moves with the current velocity, but never lets a step leave the pool
## (sideways past its edge, up through the surface, down through the floor).
func _move_in_water(delta: float) -> void:
	if _water != null:
		var step := velocity * delta
		if not _inside_water(global_position + step):
			var flat_step := Vector3(step.x, 0.0, step.z)
			if _inside_water(global_position + flat_step):
				velocity.y = 0.0
			elif _inside_water(global_position + Vector3(0.0, step.y, 0.0)):
				velocity.x = 0.0
				velocity.z = 0.0
			else:
				velocity = Vector3.ZERO
	move_and_slide()

## Is the fish's body, with the surface margin, still inside the water at `pos`?
func _inside_water(pos: Vector3) -> bool:
	return _water == null or (_water.covers_xz(pos) and pos.y + 0.7 * data.size + FISH_SURFACE_MARGIN <= _water.surface_world_y())
