class_name Arena
extends Node3D
## A circular battle zone that appears wherever the fight starts — right on
## top of the real world geometry, nobody ever goes anywhere. A ring of wall
## segments (stage_root) materializes using the world-dissolve shader (see
## WorldDissolver, driven by EncounterManager) to pen the fight in, then
## dissolves away again once it's over. Spawns orbs + enemies, tracks the
## combo and resolves victory/defeat. Bullets are parented here so they
## vanish with the arena. The EncounterManager owns its lifetime (it frees
## the arena once the barrier has dissolved away).
##
## The ground under the arena is whatever terrain was already there — not a
## flat purpose-built floor — so every spawn position is found with a
## downward raycast rather than assumed to sit at a fixed height.

signal finished(victory: bool)

const BASE_RADIUS := 11.0
const RADIUS_PER_ENEMY := 1.6
const MAX_RADIUS := 24.0
const WALL_LAYER := 1 << 6      ## physics layer 7 — blocks the player; CameraRig also
                                 ## collides with it so the camera can't peek through the
                                 ## barrier during a fight
const WALL_HEIGHT := 90.0       ## tall enough that there's no realistic camera angle
                                 ## (even zoomed out mid-fight) that sees over it
const WALL_SEGMENTS := 28       ## faceted approximation of a circle
const ORBS_BASE := 5
const ORBS_PER_ENEMY := 2
const ORB_HEIGHT := Vector2(1.8, 4.4)
const ORB_RESPAWN_DELAY := 0.9
const COMBO_BONUS := 0.25      ## +25% damage per combo step
const INTRO_DELAY := 1.0       ## enemies hold fire for this long after the reveal
const GROUND_PROBE_UP := 6.0    ## how far above a candidate point the ground raycast starts
const GROUND_PROBE_DOWN := 50.0 ## how far down it's willing to look
const MAX_GROUND_DEVIATION := 4.0  ## reject ground found further than this above/below the
                                    ## arena's own base height — stops a spot that happens to
                                    ## land on a disconnected nearby platform (or a gap with no
                                    ## floor) from reading as part of this fight
const RANDOM_POINT_ATTEMPTS := 8

var radius := BASE_RADIUS
var combo := 0
var cancelled := false
var player: Player
var enemies: Array[Enemy] = []
var orbs: Array[Orb] = []
var xp_reward := 0
var stage_root: Node3D   ## holds only the barrier wall, so WorldDissolver can
                          ## target it without touching enemies/orbs
var _over := false

static func radius_for(enemy_count: int) -> float:
	return minf(MAX_RADIUS, BASE_RADIUS + RADIUS_PER_ENEMY * maxi(0, enemy_count - 1))

## `origin` is the fight's centre, normally the player's own feet where the
## encounter was triggered. The player is never moved — the barrier simply
## rises around wherever they already are.
func begin(p: Player, origin: Vector3, roster: Array[EnemyData]) -> void:
	player = p
	global_position = origin
	radius = radius_for(roster.size())
	_build_barrier()
	_spawn_orbs(ORBS_BASE + ORBS_PER_ENEMY * roster.size())
	for d in roster:
		_spawn_enemy(d)
	if p.camera_rig:
		p.camera_rig.extra_distance = radius * 0.7
	Events.player_landed.connect(_on_player_landed)
	Events.player_died.connect(_on_player_died)
	Events.encounter_started.emit(self)

## Call once the barrier is solid; enemies start shooting after a short intro.
func start_fight() -> void:
	await get_tree().create_timer(INTRO_DELAY).timeout
	if _over:
		return
	for e in enemies:
		if is_instance_valid(e):
			e.armed = true

## Abort the fight (debug). Counts as a non-victory that ends the encounter.
func cancel() -> void:
	cancelled = true
	_end(false)

# ---------------------------------------------------------------- spawning

## A uniformly-sampled point on the ground within `fraction` of the arena's
## radius, centred on the arena. "On the ground" is found with a raycast —
## the terrain under an arena is real world geometry, not a flat floor, so it
## may slope or step within the circle. A candidate whose ground is wildly
## above/below the arena's own base height is rejected and resampled — it's
## almost always a separate platform or a gap that just happens to fall
## inside the circle's footprint, not actually part of this fight's floor.
func random_point(fraction := 1.0) -> Vector3:
	for _i in RANDOM_POINT_ATTEMPTS:
		var pos := _sample_disk(fraction)
		var h := ground_height(pos)
		if absf(h - global_position.y) <= MAX_GROUND_DEVIATION:
			pos.y = h
			return pos
	# Every attempt landed somewhere disconnected — flat at the arena's own
	# base height beats spawning on unrelated terrain.
	var pos := _sample_disk(fraction)
	pos.y = global_position.y
	return pos

func _sample_disk(fraction: float) -> Vector3:
	var r := radius * fraction * sqrt(randf())   # sqrt: uniform over the disk's area, not biased to the centre
	var ang := randf_range(0.0, TAU)
	return global_position + Vector3(cos(ang), 0.0, sin(ang)) * r

func _spawn_enemy(d: EnemyData) -> void:
	var e := Enemy.new()
	e.setup(d, self, player)
	add_child(e)
	# The placeholder sphere's pivot is at its own center, so it needs lifting
	# to sit on the ground; an animated model's origin is at its feet (same
	# convention as the player), so it needs no extra lift at all.
	var lift := 0.9 if d.model == null else 0.0
	var pos := random_point(0.6)
	pos.y += lift
	e.global_position = pos
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
		pos.y += randf_range(ORB_HEIGHT.x, ORB_HEIGHT.y)   # float above whatever ground is under it
		var nearest := INF
		for o in orbs:
			if is_instance_valid(o):
				nearest = minf(nearest, o.global_position.distance_to(pos))
		if nearest > best_d:
			best_d = nearest
			best = pos
	return best

## Casts straight down from above `pos` to find the real terrain height there
## (world geometry is collision layer 1). Falls back to the arena's own
## ground level if nothing is hit, e.g. a candidate point over a gap/ledge.
## Public: Enemy also uses this to land a leap attack on real ground.
func ground_height(pos: Vector3) -> float:
	var from := pos + Vector3.UP * GROUND_PROBE_UP
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * GROUND_PROBE_DOWN, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else global_position.y

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

# ---------------------------------------------------------------- barrier geometry

## A ring of straight wall segments approximating a circle of `radius`, plus
## a thin glowing ring at their base marking the boundary on the ground.
## Everything goes under stage_root so WorldDissolver can crumble just this,
## leaving the real world (and the enemies/orbs inside it) untouched.
func _build_barrier() -> void:
	stage_root = Node3D.new()
	add_child(stage_root)
	var wall_col := Color(1.0, 1.0, 1.0, 0.05)
	var glow_col := Color(1.0, 1.0, 1.0)
	var seg_len := TAU * radius / WALL_SEGMENTS + 0.4   # slight overlap so segments don't gap
	for i in WALL_SEGMENTS:
		var ang := TAU * float(i) / float(WALL_SEGMENTS)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var local_pos := dir * radius              # relative to the arena's own origin
		var world_pos := global_position + local_pos   # only needed to aim the ground raycast
		var ground_y := ground_height(world_pos)
		if absf(ground_y - global_position.y) > MAX_GROUND_DEVIATION:
			ground_y = global_position.y   # a disconnected platform/gap, not this fight's floor
		var local_ground_y := ground_y - global_position.y   # back to arena-local height
		var rot_y := PI * 0.5 - ang   # faces tangent to the circle at this angle

		var wall_pos := local_pos
		wall_pos.y = local_ground_y + WALL_HEIGHT * 0.5
		_slab(wall_pos, Vector3(seg_len, WALL_HEIGHT, 1.0), wall_col, WALL_LAYER, 0.0, true, rot_y)

		var ring_pos := local_pos
		ring_pos.y = local_ground_y + 0.03   # avoid z-fighting with the ground
		_decor(ring_pos, Vector3(seg_len, 0.06, 0.4), glow_col, 1.0, rot_y)

## `pos` is local to stage_root (i.e. relative to the arena's own origin),
## not a world-space coordinate — callers must not fold in global_position.
func _slab(pos: Vector3, size: Vector3, col: Color, layer: int, emit: float, translucent := false, rot_y := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = pos
	body.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.add_child(_mesh(size, col, emit, translucent))
	stage_root.add_child(body)

func _decor(pos: Vector3, size: Vector3, col: Color, emit: float, rot_y := 0.0) -> void:
	var m := _mesh(size, col, emit, false)
	m.position = pos
	m.rotation.y = rot_y
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
