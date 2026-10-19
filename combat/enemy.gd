class_name Enemy
extends Node3D
## Arena enemy: wanders inside the arena and fires its bullet patterns, plus
## (when EnemyData enables them) a telegraphed leap attack, a burst-shoot
## volley, and/or a damaging slime trail. It has no collision; it only takes
## damage through the arena's orb system.

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
var _flash := 0.0
var _dying := false   ## true once defeated, so a lingering death animation isn't overridden

var _special_t := 0.0          ## countdown to the next leap/burst-shoot attack
var _busy_with_special := false ## true while a leap or burst-shoot is actually playing out
var _puddle_t := 0.0

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
	_dest = global_position

func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not _busy_with_special:
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

func _move(delta: float) -> void:
	var flat := _dest - global_position
	flat.y = 0.0
	if flat.length() < 0.5:
		_dest = arena.random_point(0.8)
		_dest.y = global_position.y
		if _visual:
			_visual.play_idle()
		return
	var dir := flat.normalized()
	global_position += dir * data.move_speed * delta
	_face(dir, delta)
	if _visual:
		_visual.play_move()

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

func take_damage(amount: float) -> void:
	hp -= amount
	_flash = 0.12
	if _visual:
		_visual.flash()
	if hp <= 0.0:
		_dying = true
		defeated.emit(self)
		if _visual:
			var death_len := _visual.play_death()
			if death_len > 0.0:
				get_tree().create_timer(death_len).timeout.connect(queue_free)
				return
		queue_free()

# ---------------------------------------------------------------- slime trail

func _update_puddle_trail(delta: float) -> void:
	if not data.leaves_puddle_trail:
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
	await get_tree().create_timer(data.leap_ready_time).timeout
	if _dying:
		return

	var start := global_position
	var land := _clamped_landing_point(target.global_position)
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
			return

	global_position = land
	rotation = Vector3.ZERO   # land upright, whatever the tumble left it at
	_land_leap(land)

## Keeps a leap from landing outside the arena (e.g. the player hugging the
## wall) and settles it onto real ground.
func _clamped_landing_point(raw: Vector3) -> Vector3:
	var flat := raw - arena.global_position
	flat.y = 0.0
	var limit := arena.radius * 0.85
	if flat.length() > limit:
		flat = flat.normalized() * limit
	var land := arena.global_position + flat
	land.y = arena.ground_height(land)
	return land

func _land_leap(land: Vector3) -> void:
	if data.leaves_puddle_trail:
		_spawn_puddle(land, data.puddle_radius * data.puddle_landing_radius_mult)
	if is_instance_valid(target) and target is Player and not (target as Player).dead:
		if target.global_position.distance_to(land) <= data.leap_radius:
			(target as Player).hit(data.leap_damage)

## A machine-gun-style volley: a randomized number of aimed shots, each
## re-triggering anim_shoot and colored with this enemy's accent color.
func _do_burst_shoot() -> void:
	var count := randi_range(data.shoot_count_min, data.shoot_count_max)
	for _i in count:
		if _dying or not is_instance_valid(target):
			return
		_face_point_instant(target.global_position)
		if _visual:
			_visual.play_shoot()
		_fire_slime_ball()
		await get_tree().create_timer(data.shoot_interval).timeout

func _fire_slime_ball() -> void:
	var dir := target.global_position - global_position
	if dir.length() < 0.01:
		return
	var b := Bullet.new()
	b.damage = data.shoot_damage
	b.velocity = dir.normalized() * data.shoot_speed
	b.color_override = data.color
	arena.add_child(b)
	b.global_position = global_position
