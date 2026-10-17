class_name Arena
extends Node3D
## Square battle stage with a real floor and collision walls (so wall bounces work).
## Spawns orbs + enemies, tracks the combo and resolves victory/defeat.
## Bullets are parented here so they vanish with the arena. The EncounterManager
## owns its lifetime (it frees the arena after the return transition).

signal finished(victory: bool)

const BASE_HALF := 11.0        ## half side length; side = 2 * half
const HALF_PER_ENEMY := 1.6
const MAX_HALF := 24.0
const WALL_HEIGHT := 14.0
const ORBS_BASE := 5
const ORBS_PER_ENEMY := 2
const ORB_HEIGHT := Vector2(1.8, 4.4)
const ORB_RESPAWN_DELAY := 0.9
const COMBO_BONUS := 0.25      ## +25% damage per combo step
const INTRO_DELAY := 1.0       ## enemies hold fire for this long after the reveal

var half := BASE_HALF
var combo := 0
var cancelled := false
var player: Player
var enemies: Array[Enemy] = []
var orbs: Array[Orb] = []
var xp_reward := 0
var stage_root: Node3D   ## holds only the floor/walls/border, so WorldDissolver can
                          ## target the stage geometry without touching enemies/orbs
var _over := false

static func half_for(enemy_count: int) -> float:
	return minf(MAX_HALF, BASE_HALF + HALF_PER_ENEMY * maxi(0, enemy_count - 1))

## `origin` is the stage floor centre. Teleports the player onto the stage.
func begin(p: Player, origin: Vector3, roster: Array[EnemyData]) -> void:
	player = p
	global_position = origin
	half = half_for(roster.size())
	_build_stage()
	_spawn_orbs(ORBS_BASE + ORBS_PER_ENEMY * roster.size())
	for d in roster:
		_spawn_enemy(d)
	p.teleport(origin + Vector3(0.0, 0.3, half * 0.55))
	p.face(Vector3.FORWARD)
	if p.camera_rig:
		p.camera_rig.yaw = 0.0
		p.camera_rig.extra_distance = half * 0.7
		p.camera_rig.snap()
	Events.player_landed.connect(_on_player_landed)
	Events.player_died.connect(_on_player_died)
	Events.encounter_started.emit(self)

## Call once the stage is visible; enemies start shooting after a short intro.
func start_fight() -> void:
	await get_tree().create_timer(INTRO_DELAY).timeout
	if _over:
		return
	for e in enemies:
		if is_instance_valid(e):
			e.armed = true

## Abort the fight (debug). Counts as a non-victory that returns to the overworld.
func cancel() -> void:
	cancelled = true
	_end(false)

# ---------------------------------------------------------------- spawning

func random_point(fraction := 1.0) -> Vector3:
	return global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * half * fraction

func _spawn_enemy(d: EnemyData) -> void:
	var e := Enemy.new()
	e.setup(d, self, player)
	add_child(e)
	e.global_position = random_point(0.6) + Vector3.UP * 0.9
	e.defeated.connect(_on_enemy_defeated)
	enemies.append(e)

func _spawn_orbs(count: int) -> void:
	for i in count:
		var o := Orb.new()
		add_child(o)
		o.global_position = _free_orb_position()
		o.hit.connect(_on_orb_hit)
		orbs.append(o)

func _free_orb_position() -> Vector3:
	var best := Vector3.ZERO
	var best_d := -1.0
	for _i in 12:   # best-candidate sampling keeps orbs spread out
		var pos := random_point(0.9)
		pos.y = global_position.y + randf_range(ORB_HEIGHT.x, ORB_HEIGHT.y)
		var nearest := INF
		for o in orbs:
			if is_instance_valid(o):
				nearest = minf(nearest, o.global_position.distance_to(pos))
		if nearest > best_d:
			best_d = nearest
			best = pos
	return best

# ---------------------------------------------------------------- combat

func _on_orb_hit(orb: Orb) -> void:
	if _over:
		return
	combo += 1
	var dmg := Game.stats.damage() * (1.0 + COMBO_BONUS * (combo - 1))
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.take_damage(dmg)   # same damage to every enemy
	player.bounce_off_orb()
	Events.orb_hit.emit(combo, dmg)
	Events.combo_changed.emit(combo)
	get_tree().create_timer(ORB_RESPAWN_DELAY).timeout.connect(func():
		if is_instance_valid(orb) and not _over:
			orb.relocate(_free_orb_position()))

func _on_player_landed() -> void:
	if combo > 0:
		combo = 0
		Events.combo_changed.emit(0)

func _on_enemy_defeated(e: Enemy) -> void:
	enemies.erase(e)
	xp_reward += e.data.xp
	if enemies.is_empty():
		_end(true)

func _on_player_died() -> void:
	_end(false)

func _end(victory: bool) -> void:
	if _over:
		return
	_over = true
	Events.player_landed.disconnect(_on_player_landed)
	Events.player_died.disconnect(_on_player_died)
	for c in get_children():
		if c is Bullet:
			c.queue_free()
	if player.camera_rig:
		player.camera_rig.extra_distance = 0.0
	if victory:
		Game.stats.add_xp(xp_reward)
	Events.combo_changed.emit(0)
	Events.encounter_ended.emit(self, victory)
	finished.emit(victory)

# ---------------------------------------------------------------- stage geometry

func _build_stage() -> void:
	stage_root = Node3D.new()
	add_child(stage_root)
	var side := half * 2.0
	# Floor (top surface at local y = 0)
	_slab(Vector3(0, -0.5, 0), Vector3(side + 2.0, 1.0, side + 2.0), Color(0.07, 0.09, 0.16), 1, 0.0)
	# Glowing floor border
	var glow := Color(0.3, 0.9, 1.0)
	for sgn in [-1.0, 1.0]:
		_decor(Vector3(0, 0.03, sgn * (half - 0.2)), Vector3(side, 0.06, 0.4), glow, 1.0)
		_decor(Vector3(sgn * (half - 0.2), 0.03, 0), Vector3(0.4, 0.06, side), glow, 1.0)
	# Collision walls (layer 7: block the player, not the camera) + faint panels
	var wall_layer := 1 << 6
	for sgn in [-1.0, 1.0]:
		_slab(Vector3(0, WALL_HEIGHT * 0.5, sgn * (half + 0.5)), Vector3(side + 2.0, WALL_HEIGHT, 1.0), Color(0.3, 0.9, 1.0, 0.05), wall_layer, 0.0, true)
		_slab(Vector3(sgn * (half + 0.5), WALL_HEIGHT * 0.5, 0), Vector3(1.0, WALL_HEIGHT, side + 2.0), Color(0.3, 0.9, 1.0, 0.05), wall_layer, 0.0, true)

func _slab(pos: Vector3, size: Vector3, col: Color, layer: int, emit: float, translucent := false) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.add_child(_mesh(size, col, emit, translucent))
	stage_root.add_child(body)

func _decor(pos: Vector3, size: Vector3, col: Color, emit: float) -> void:
	var m := _mesh(size, col, emit, false)
	m.position = pos
	stage_root.add_child(m)

func _mesh(size: Vector3, col: Color, emit: float, translucent: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emit
	if translucent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi
