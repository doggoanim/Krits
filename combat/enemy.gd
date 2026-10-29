class_name Enemy
extends CharacterBody3D
## Arena enemy: wanders inside the arena and fires its bullet patterns, plus
## (when EnemyData enables them) a telegraphed leap attack, a burst-shoot
## volley, and/or a damaging slime trail. It has real physics now (gravity,
## slopes, bumping into world geometry, arena walls and other enemies, knockback
## from hits) but does not block the player; it only takes damage through the
## arena's orb system.

signal defeated(enemy: Enemy)

var data: EnemyData
var hp := 1.0
var arena: Arena
var target: Node3D
var armed := false   ## only attacks once the arena starts the fight

var _timers: Array[float] = []
var _steps: Array[int] = []
var _dest := Vector3.ZERO
var _mesh: MeshInstance3D   ## placeholder sphere, only built when data.model is unset
var _mat := StandardMaterial3D.new()
var _visual: EnemyVisual    ## animated model, only built when data.model is set
var _fx: StatusFx           ## burn / slow / stun visuals — see StatusFx
var _flash := 0.0
var _dying := false   ## true once defeated, so a lingering death animation isn't overridden

var _special_t := 0.0          ## countdown to the next leap/burst-shoot attack
var _busy_with_special := false ## true while a leap or burst-shoot is actually playing out
var _puddle_t := 0.0
var _last_was_leap := false    ## which special attack ran last (see _run_special_attack)
var _repeat_count := 0         ## how many times in a row that same kind has run

## ---- status effects (Staff's elemental orbs — see Orb.Kind/Arena) -------
## Each is independent and just ticks down on its own; nothing here stops
## _move()/_shoot() except _stun_t (checked in _physics_process()), and none
## of them interrupt a leap/burst-shoot already in progress (that's an
## in-flight coroutine — safely cancelling it mid-arc isn't worth the
## complexity this is meant to add, a battlefield debuff, not a hard stop).
var _speed_mult := 1.0
var _lead_scale := 1.0         ## prediction strength of the next shot; shrinks through a volley
var _slow_t := 0.0
var _stun_t := 0.0
var _burn_dps := 0.0
var _burn_t := 0.0

## ---- physics -------------------------------------------------------------
const GRAVITY := 30.0
const KNOCK_FRICTION := 9.0        ## horizontal knockback decay on the ground (m/s per second)
const KNOCK_FRICTION_AIR := 1.5
const STAGGER_TIME := 0.4          ## can't walk for this long after being knocked back
const STEP_DISTANCE := 1.1          ## metres between footstep sounds
const SFX_BUS := &"SFX"
const SFX_PITCH_VARIANCE := 0.1
const STUCK_CHECK_TIME := 0.6      ## how often "am I actually getting anywhere?" is checked
const ENEMY_LAYER := 1 << 2        ## physics layer 3: enemy
const COLLIDE_MASK := 1 | (1 << 6) | (1 << 2)   ## world, arena walls, other enemies (not the player)
var _walk := Vector3.ZERO          ## horizontal velocity the AI wants this frame
var _knock := Vector3.ZERO         ## horizontal knockback velocity, decays by itself
var _stagger_t := 0.0
var _stuck_t := 0.0
var _stuck_from := Vector3.ZERO
var _step_dist := 0.0              ## distance walked since the last footstep sound

## Body size derived from EnemyData — used for the collider and (by Arena) to
## check a spawn spot is clear and to stand the enemy on the ground.
static func body_height(d: EnemyData) -> float:
	return d.model_height if d.model else 1.4 * d.size

static func body_radius(d: EnemyData) -> float:
	return 0.7 * d.size if d.model == null else clampf(d.model_height * 0.28, 0.3, 1.5)

## Distance from the node's origin down to its feet (the placeholder sphere is
## pivoted at its centre, a model at its feet).
static func feet_offset(d: EnemyData) -> float:
	return 0.7 * d.size if d.model == null else 0.0

const FACE_TURN_SPEED := 8.0   ## rad/s, how fast an enemy turns to face its movement
const SPHERE_OUTLINE_RATIO := 0.08   ## placeholder-sphere outline thickness, as a fraction of its radius

func setup(d: EnemyData, a: Arena, t: Node3D) -> void:
	data = d
	arena = a
	target = t
	hp = d.max_hp
	for p in d.patterns:
		_timers.append(randf_range(0.5, p.interval))   # desync groups
		_steps.append(0)
	if d.has_leap() or d.has_burst_shoot():
		_special_t = randf_range(1.0, 2.0)   # brief delay after the intro before the first one

func _ready() -> void:
	collision_layer = ENEMY_LAYER
	collision_mask = COLLIDE_MASK
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55.0)
	_build_collider()
	if data.model:
		_visual = EnemyVisual.new()
		add_child(_visual)
		_visual.setup(data)
	else:
		var sphere_radius := 0.7 * data.size
		var sm := SphereMesh.new()
		sm.radius = sphere_radius
		sm.height = 1.4 * data.size
		_mesh = MeshInstance3D.new()
		_mesh.mesh = sm
		_mat.albedo_color = data.color
		# Cel-shaded to match the character: hard light/shadow bands, no shiny highlight.
		_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_mesh.material_override = _mat
		add_child(_mesh)
		CelOutline.apply(_mesh, sphere_radius * SPHERE_OUTLINE_RATIO)
	_fx = StatusFx.new()
	add_child(_fx)
	_fx.setup(_visual, body_height(data) * 0.5 - feet_offset(data), body_height(data), body_radius(data))
	_dest = global_position

func _build_collider() -> void:
	var cs := CollisionShape3D.new()
	var r := body_radius(data)
	if data.model:
		var cap := CapsuleShape3D.new()
		var h := body_height(data)
		cap.radius = r
		cap.height = maxf(h, r * 2.0)
		cs.shape = cap
		cs.position.y = h * 0.5
	else:
		var sph := SphereShape3D.new()
		sph.radius = r
		cs.shape = sph
	add_child(cs)

func _physics_process(delta: float) -> void:
	_walk = Vector3.ZERO
	if not _dying:
		_update_status_effects(delta)
	if not _dying:
		if _stun_t <= 0.0 and not _busy_with_special:
			_move(delta)
			_shoot(delta)
		_update_puddle_trail(delta)
		_update_special_attacks(delta)
		if _mesh:
			if _flash > 0.0:
				_flash -= delta
				_mat.albedo_color = Color.WHITE
			else:
				_mat.albedo_color = data.color
	_apply_physics(delta)

## Gravity, walking, knockback and collision in one place. While a leap or
## burst-shoot is playing out, that coroutine owns the position instead.
func _apply_physics(delta: float) -> void:
	if _busy_with_special:
		velocity = Vector3.ZERO
		return
	var on_floor := is_on_floor()
	var horizontal := _knock + (_walk if _stagger_t <= 0.0 else Vector3.ZERO)
	_knock = _knock.move_toward(Vector3.ZERO, (KNOCK_FRICTION if on_floor else KNOCK_FRICTION_AIR) * delta)
	_stagger_t = maxf(0.0, _stagger_t - delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if on_floor and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	var before := global_position
	move_and_slide()
	if on_floor and not _walk.is_zero_approx():
		_step_dist += Vector2(global_position.x - before.x, global_position.z - before.z).length()
		if _step_dist >= STEP_DISTANCE:
			_step_dist = 0.0
			_play_random_sfx(data.sfx_footsteps)

## World-space middle of the body (a model's origin is at its feet, the
## placeholder sphere's at its centre) — where shots come out and what hits aim at.
func center_point() -> Vector3:
	return global_position + Vector3.UP * (body_height(data) * 0.5 - feet_offset(data))

func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-SFX_PITCH_VARIANCE, SFX_PITCH_VARIANCE)
	p.bus = SFX_BUS
	arena.add_child(p)
	p.global_position = global_position
	p.play()
	p.finished.connect(p.queue_free)

func _play_random_sfx(pool: Array[AudioStream]) -> void:
	if not pool.is_empty():
		_play_sfx(pool.pick_random())

## Shoves the enemy away from `from_pos` and pops it into the air; it
## staggers (can't walk) until it has landed and recovered.
func knockback(from_pos: Vector3, strength: float) -> void:
	if _busy_with_special:
		return
	var away := global_position - from_pos
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_knock = away.normalized() * strength
	velocity.y = strength * 1.1
	_stagger_t = STAGGER_TIME

func _move(delta: float) -> void:
	if not armed:
		# Stand still through the barrier materializing and the intro delay —
		# matches the player, who's also locked out of input for that whole
		# stretch (see EncounterManager). Without this an enemy would already
		# be wandering around while the player can't do anything about it yet.
		if _visual:
			_visual.play_idle()
		return
	var flat := _dest - global_position
	flat.y = 0.0
	if flat.length() < 0.5:
		_dest = arena.random_point(0.8)
		_dest.y = global_position.y
		if _visual:
			_visual.play_idle()
		return
	var dir := flat.normalized()
	_walk = dir * data.move_speed * _speed_mult
	_check_stuck(delta)
	_face(dir, delta)
	if _visual:
		_visual.play_move()

## If the enemy keeps walking but isn't getting anywhere (jammed against a
## rock or another enemy), give up on that destination and pick a new one.
func _check_stuck(delta: float) -> void:
	_stuck_t += delta
	if _stuck_t < STUCK_CHECK_TIME:
		return
	var expected := data.move_speed * _speed_mult * _stuck_t
	var moved := Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
	if moved < expected * 0.25:
		_dest = arena.random_point(0.8)
	_stuck_t = 0.0
	_stuck_from = global_position

## Smoothly yaws the enemy to face its movement direction (same atan2
## convention as Player.face()). Only ever called from _move(), which itself
## only runs while not _busy_with_special — so this never fights with the
## leap attack's own tumble/rotate().
func _face(dir: Vector3, delta: float) -> void:
	var target := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target, minf(1.0, FACE_TURN_SPEED * delta))

## Snaps (no lerp) to face a world point — used for the burst-shoot volley,
## which fires fast enough that a smoothed turn would visibly lag behind.
## Only looks at the horizontal direction, so it works the same whether the
## enemy happens to be grounded or airborne.
func _face_point_instant(point: Vector3) -> void:
	var dir := point - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	rotation.y = atan2(-dir.x, -dir.z)

func _shoot(delta: float) -> void:
	if not armed:
		return
	for i in data.patterns.size():
		_timers[i] -= delta
		if _timers[i] <= 0.0:
			var p := data.patterns[i]
			_timers[i] = p.interval
			p.fire(global_position, target.global_position, arena, _steps[i])
			_steps[i] += 1

## Slows movement to `mult` of normal for `duration` — refreshes rather than
## stacking (a second Ice hit while already slowed just extends it, doesn't
## compound the multiplier).
func apply_slow(mult: float, duration: float) -> void:
	_speed_mult = mult
	_slow_t = duration
	_fx.set_active(&"slow", true)

## Stops _move()/_shoot() entirely for `duration` — takes the longer of the
## current and new duration rather than stacking, same reasoning as slow.
func apply_stun(duration: float) -> void:
	_stun_t = maxf(_stun_t, duration)
	_fx.set_active(&"stun", true)

## Ticks `dps` damage per second for `duration`, refreshing like slow (a
## second Fire hit resets the burn's clock rather than adding a second,
## independent burn on top).
func apply_burn(dps: float, duration: float) -> void:
	_burn_dps = dps
	_burn_t = duration
	_fx.set_active(&"burn", true)

func _update_status_effects(delta: float) -> void:
	if _slow_t > 0.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			_speed_mult = 1.0
			_fx.set_active(&"slow", false)
	if _stun_t > 0.0:
		_stun_t -= delta
		if _stun_t <= 0.0:
			_fx.set_active(&"stun", false)
	if _burn_t > 0.0:
		_burn_t -= delta
		take_damage(_burn_dps * delta)
		if _burn_t <= 0.0:
			_fx.set_active(&"burn", false)

## Squash-and-stretch reaction for a heavy hit (Arena calls it once per landed
## combo — not from take_damage(), which burn damage calls every frame).
func punch() -> void:
	var node: Node3D = _visual if _visual else _mesh
	if node == null:
		return
	node.scale = Vector3(1.35, 0.6, 1.35)
	create_tween().tween_property(node, "scale", Vector3.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func take_damage(amount: float) -> void:
	hp -= amount
	_flash = 0.12
	if _visual:
		_visual.flash()
	if hp <= 0.0:
		_dying = true
		_fx.clear_all()
		defeated.emit(self)
		if _visual:
			var death_len := _visual.play_death()
			if death_len > 0.0:
				get_tree().create_timer(death_len).timeout.connect(queue_free)
				return
		queue_free()

# ---------------------------------------------------------------- slime trail

func _update_puddle_trail(delta: float) -> void:
	if not armed or not data.leaves_puddle_trail:
		return
	_puddle_t -= delta
	if _puddle_t <= 0.0:
		_puddle_t = data.puddle_interval
		_spawn_puddle(global_position, data.puddle_radius)

## `pos` only needs to be roughly where the puddle should sit horizontally —
## its height always comes from an actual ground probe, never the caller's
## y. That matters most during the leap attack, where _run_special_attack's
## trail calls this mid-arc with the slime's current (airborne) position;
## without re-grounding here the puddle would spawn floating at leap height
## instead of on the floor beneath.
func _spawn_puddle(pos: Vector3, radius: float) -> void:
	var p := SlimePuddle.new()
	p.radius = radius
	p.color = data.color
	p.damage = data.puddle_damage
	p.tick_interval = data.puddle_tick_interval
	p.lifetime = data.puddle_lifetime
	arena.add_child(p)
	var ground_pos := pos
	ground_pos.y = arena.ground_height(pos)
	p.global_position = ground_pos

# ---------------------------------------------------------------- special attacks

func _update_special_attacks(delta: float) -> void:
	if not armed or _busy_with_special:
		return
	if not (data.has_leap() or data.has_burst_shoot()):
		return
	_special_t -= delta
	if _special_t > 0.0:
		return
	_run_special_attack()

func _run_special_attack() -> void:
	_busy_with_special = true
	# Pick whichever attacks are actually configured; if both are, coin-flip.
	var use_leap := data.has_leap() and (not data.has_burst_shoot() or randf() < 0.5)
	# Never the same attack three times running: after two in a row of one
	# kind, the other one is forced (when the enemy has both).
	if data.has_leap() and data.has_burst_shoot() and _repeat_count >= 2:
		use_leap = not _last_was_leap
	_repeat_count = _repeat_count + 1 if use_leap == _last_was_leap else 1
	_last_was_leap = use_leap
	if use_leap:
		await _do_leap_attack()
		if _dying:
			return
		_special_t = randf_range(data.leap_min_cooldown, data.leap_max_cooldown)
	else:
		await _do_burst_shoot()
		if _dying:
			return
		_special_t = randf_range(data.shoot_min_cooldown, data.shoot_max_cooldown)
	_busy_with_special = false

## Telegraphs with anim_leap_ready, then arcs toward wherever the player was
## standing when the leap committed (snapshotted once, not homed — it's
## meant to be dodgeable), tumbling the whole body as it travels, and lands
## in a damaging burst that also drops a (bigger) puddle.
func _do_leap_attack() -> void:
	if _visual:
		_visual.play_leap_ready()
	# Telegraph: a "!" and a landing circle that follows the player and fills
	# up over leap_ready_time, then locks where the leap will actually land.
	Telegraph.exclaim(self, body_height(data) + 0.5)
	var zone := Telegraph.circle(arena, data.leap_radius)
	var waited := 0.0
	while waited < data.leap_ready_time:
		if _dying or not is_instance_valid(target):
			zone.queue_free()
			return
		_place_leap_zone(zone)
		zone.set_fill(waited / data.leap_ready_time)
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	if _dying:
		zone.queue_free()
		return
	_place_leap_zone(zone)
	zone.lock()

	var start := global_position
	var land := _clamped_landing_point(target.global_position)
	_play_sfx(data.sfx_leap)
	if _visual:
		_visual.play_leap()

	var dur := maxf(0.05, data.leap_travel_time)
	var spin_axis := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	var spin_speed := randf_range(4.0, 7.0)   # rad/s — a few tumbles over the arc
	var t := 0.0
	var puddle_t := 0.0
	while t < dur:
		var delta := get_physics_process_delta_time()
		t += delta
		var frac := clampf(t / dur, 0.0, 1.0)
		var pos := start.lerp(land, frac)
		pos.y += sin(frac * PI) * data.leap_height
		global_position = pos
		rotate(spin_axis, spin_speed * delta)
		if data.leaves_puddle_trail:
			puddle_t -= delta
			if puddle_t <= 0.0:
				puddle_t = data.puddle_interval
				_spawn_puddle(global_position, data.puddle_radius)
		await get_tree().physics_frame
		if _dying:
			zone.queue_free()
			return

	global_position = land
	rotation = Vector3.ZERO   # land upright, whatever the tumble left it at
	_play_sfx(data.sfx_land)
	_land_leap(land)
	zone.fade_out()

func _place_leap_zone(zone: Telegraph) -> void:
	var land := _clamped_landing_point(target.global_position)
	zone.global_position = Vector3(land.x, land.y - feet_offset(data) + Telegraph.FLOOR_LIFT, land.z)

## Keeps a leap from landing outside the arena (e.g. the player hugging the
## wall) and settles it onto real ground.
func _clamped_landing_point(raw: Vector3) -> Vector3:
	var flat := raw - arena.global_position
	flat.y = 0.0
	var limit := arena.radius * 0.85
	if flat.length() > limit:
		flat = flat.normalized() * limit
	var land := arena.global_position + flat
	land.y = arena.ground_height(land) + feet_offset(data)
	return land

func _land_leap(land: Vector3) -> void:
	if data.leaves_puddle_trail:
		_spawn_puddle(land, data.puddle_radius * data.puddle_landing_radius_mult)
	if is_instance_valid(target) and target is Player and not (target as Player).dead:
		if target.global_position.distance_to(land) <= data.leap_radius:
			(target as Player).hit(data.leap_damage, false, global_position)

## A machine-gun-style volley: a randomized number of aimed shots, each
## re-triggering anim_shoot and colored with this enemy's accent color.
func _do_burst_shoot() -> void:
	var count := randi_range(data.shoot_count_min, data.shoot_count_max)
	_lead_scale = 1.0
	# Telegraph: "!" + an aim line that tracks the player through the wind-up
	# and the whole volley.
	Telegraph.exclaim(self, body_height(data) + 0.5)
	var aim := Telegraph.line(arena, 0.3)
	if _visual:
		_visual.play_idle()
	if not await _wait_aiming(data.shoot_ready_time, aim):
		return
	# The first gap is just past the player's invincibility window, so a ball
	# that lands finds the i-frames from the previous hit already over; every
	# following gap is shoot_rate_ramp times shorter than the one before, so
	# the volley speeds up (later balls can arrive inside i-frames — dodge!).
	var spacing := maxf(data.shoot_interval, Player.HIT_INVULN + 0.02)
	for i in count:
		if _dying or not is_instance_valid(target):
			aim.queue_free()
			return
		_face_point_instant(_predicted_point())
		if _visual:
			_visual.play_shoot()
		_fire_slime_ball()
		_lead_scale *= data.shoot_lead_falloff   # the next shot predicts worse
		if i < count - 1:
			if not await _wait_aiming(spacing, aim):
				return
			spacing /= maxf(data.shoot_rate_ramp, 1.0)
	aim.fade_out()

## Waits `seconds` (physics time) while keeping the aim line and facing on
## the player. False if the enemy died / the target vanished meanwhile (the
## line is cleaned up then).
func _wait_aiming(seconds: float, aim: Telegraph) -> bool:
	var waited := 0.0
	while waited < seconds:
		if _dying or not is_instance_valid(target):
			aim.queue_free()
			return false
		var aim_at := _predicted_point()
		aim.set_line(center_point(), aim_at)
		_face_point_instant(aim_at)
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return true

## Where shots aim: the player's chest, not their feet.
func _aim_point() -> Vector3:
	return target.global_position + Vector3.UP * (Player.STAND_HEIGHT * 0.55)

## Where the player will be when a ball fired now arrives (ULTRAKILL-style
## lead). Solves "ball speed vs. player's horizontal velocity" for the
## intercept time; falls back to the current position if there is no
## solution (player outrunning the ball) or the enemy has shoot_lead = 0.
## Vertical motion is ignored — jumps/falls are too short-lived to lead.
func _predicted_point() -> Vector3:
	var here := _aim_point()
	if data.shoot_lead <= 0.0 or not (target is CharacterBody3D):
		return here
	var v := (target as CharacterBody3D).velocity
	v.y = 0.0
	var rel := here - center_point()
	rel.y = 0.0
	var s := data.shoot_speed
	# |rel + v*t| = s*t  ->  (v.v - s^2) t^2 + 2 (rel.v) t + rel.rel = 0
	var a := v.dot(v) - s * s
	var b := 2.0 * rel.dot(v)
	var c := rel.dot(rel)
	var t := 0.0
	if absf(a) < 0.0001:
		t = -c / b if absf(b) > 0.0001 else 0.0
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var root := sqrt(disc)
			var t1 := (-b - root) / (2.0 * a)
			var t2 := (-b + root) / (2.0 * a)
			t = minf(t1, t2) if t1 > 0.0 and t2 > 0.0 else maxf(t1, t2)
	t = clampf(t, 0.0, 1.5) * data.shoot_lead * _lead_scale
	return here + v * t

func _fire_slime_ball() -> void:
	var origin := center_point()   # from the middle of the body, not the pivot at its feet
	var dir := _predicted_point() - origin
	if dir.length() < 0.01:
		return
	var b := Bullet.new()
	b.damage = data.shoot_damage
	b.velocity = dir.normalized() * data.shoot_speed
	b.color_override = data.color
	b.radius = data.shoot_ball_radius
	arena.add_child(b)
	b.global_position = origin
	_play_random_sfx(data.sfx_shoot)
