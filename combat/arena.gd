class_name Arena
extends Node3D
## A circular battle zone that appears wherever the fight starts — right on
## top of the real world geometry, nobody ever goes anywhere. A ring of wall
## segments (stage_root) reveals itself (see play_intro(): the ground ring
## sweeps around first, then the walls grow straight up) to pen the fight in,
## then dissolves away again once it's over using the world-dissolve shader
## (see WorldDissolver, driven by EncounterManager — the teardown is the only
## side still using it; play_intro() tried that too but reverted it, see its
## own doc comment for why). Spawns orbs (falling in from overhead, see
## Orb.drop_in()) + enemies, tracks the combo and resolves victory/defeat.
## Bullets are parented here so they vanish with the arena. The
## EncounterManager owns its lifetime (it frees the arena once the barrier
## has dissolved away).
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
const WALL_DEPTH_BELOW_GROUND := 20.0   ## how far the wall's COLLIDER (only) extends below
                                 ## the ground height sampled at its segment's center —
                                 ## the terrain can dip within a segment's own span even
                                 ## though only its center point is raycast, which left a
                                 ## gap a player could slide/roll under at the segment's
                                 ## edges; purely underground so it's never visible
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

## ---- reveal sequence (see play_intro()) ----
const RING_DRAW_TIME := 0.5     ## total time for the ground ring to sweep fully around
const RING_POP_TIME := 0.12     ## how long each individual ring segment's own pop-in takes
const WALL_GROW_TIME := 0.45    ## how long the walls take to rise once the ring's done
const ORB_DROP_HEIGHT := 9.0    ## how far above its landing spot each orb starts
const ORB_DROP_TIME := 0.6
const ORB_DROP_STAGGER := 0.05  ## added delay per orb so they don't all land in lockstep

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
var _wall_meshes: Array[MeshInstance3D] = []   ## one per wall segment — see play_intro()
var _ring_pieces: Array[MeshInstance3D] = []   ## one per ground-ring segment, same order/angle
                                                ## as _wall_meshes

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

## The arena's reveal: the ground ring sweeps around first (each segment pops
## in with a short delay from the last, following the same angular order
## _build_barrier() placed them in), then the wall segments grow straight up
## out of the ground once the ring's finished. Awaited by EncounterManager
## before unlocking the player. Orbs are dropping in on their own timers at
## the same time (see _spawn_orbs()/Orb.drop_in()) — nothing here needs to
## wait on them specifically.
##
## NOTE: this used to also run WorldDissolver's shared world-dissolve shader
## across the reveal (materializing out of noise like the teardown does, in
## reverse). Reverted — that shader is `unshaded, cull_back` with no alpha
## output at all, which is fine for the teardown (the walls are vanishing
## anyway) but wrong for an intro the player watches from *inside* the
## barrier: the translucent walls briefly render fully opaque, and cull_back
## can make them disappear entirely from the inside-facing side.
func play_intro() -> void:
	for mesh in _wall_meshes:
		mesh.scale.y = 0.0
	for piece in _ring_pieces:
		piece.scale = Vector3.ZERO

	var ring_tween := create_tween()
	ring_tween.set_parallel(true)
	for i in _ring_pieces.size():
		var start_t := RING_DRAW_TIME * float(i) / float(_ring_pieces.size())
		ring_tween.tween_property(_ring_pieces[i], "scale", Vector3.ONE, RING_POP_TIME) \
				.set_delay(start_t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await ring_tween.finished

	var wall_tween := create_tween()
	wall_tween.tween_method(_set_wall_growth, 0.0, 1.0, WALL_GROW_TIME) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await wall_tween.finished

## Grows every wall segment's mesh up from the ground together, `t` 0..1.
## Scaling just the mesh (not its StaticBody3D/collider, which stays full
## size throughout — the player's frozen for the whole reveal anyway, so
## there's nothing for a not-yet-visible collider to awkwardly block) keeps
## the ground edge fixed in place instead of growing from the segment's
## vertical center in both directions at once.
func _set_wall_growth(t: float) -> void:
	for mesh in _wall_meshes:
		mesh.scale.y = t
		mesh.position.y = -WALL_HEIGHT * 0.5 * (1.0 - t)

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

## Picks each orb's landing spot up front (so the spread-out spacing check
## compares real target positions, not an orb still mid-fall overhead — see
## _free_orb_position()), then drops them all in with a per-orb stagger.
func _spawn_orbs(count: int) -> void:
	var targets: Array[Vector3] = []
	for i in count:
		var o := Orb.new()
		add_child(o)
		var pos := _free_orb_position(targets)
		targets.append(pos)
		o.hit.connect(_on_orb_hit)
		orbs.append(o)
		o.drop_in(pos, ORB_DROP_HEIGHT, ORB_DROP_TIME, i * ORB_DROP_STAGGER)

## A ground spot kept away from `existing` positions (best-candidate sampling).
## Callers pass whatever set of positions should count as "already taken" —
## other orbs' chosen landing spots during the initial spawn, or the current
## (landed) orbs' live positions when relocating one after a hit.
func _free_orb_position(existing: Array[Vector3]) -> Vector3:
	var best := Vector3.ZERO
	var best_d := -1.0
	for _i in 12:   # best-candidate sampling keeps orbs spread out
		var pos := random_point(0.9)
		pos.y += randf_range(ORB_HEIGHT.x, ORB_HEIGHT.y)   # float above whatever ground is under it
		var nearest := INF
		for t in existing:
			nearest = minf(nearest, t.distance_to(pos))
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
	player.bounce_off_orb(combo)
	if _over:
		# That damage just finished off the last enemy — take_damage()'s
		# defeat chain ran synchronously inside the loop above and already
		# called _end(), which reset the combo to 0 for the HUD. Emitting
		# this hit's own (now-stale) nonzero combo below would stomp that
		# reset right back to the finishing count, and with the fight over
		# there's no later hit or landing left to clear it again — it would
		# just sit there on screen. Skip it instead.
		return
	Events.orb_hit.emit(combo, dmg)
	Events.combo_changed.emit(combo)
	get_tree().create_timer(ORB_RESPAWN_DELAY).timeout.connect(func():
		if is_instance_valid(orb) and not _over:
			var taken: Array[Vector3] = []
			for o in orbs:
				if is_instance_valid(o):
					taken.append(o.global_position)
			orb.relocate(_free_orb_position(taken)))

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
	for o in orbs:
		if is_instance_valid(o):
			o.break_apart()   # any orbs still unclaimed break instead of just vanishing
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
	_wall_meshes.clear()
	_ring_pieces.clear()
	var wall_col := Color(1.0, 1.0, 1.0, 0.16)   ## one solid translucent white, same on every segment
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
		_wall_meshes.append(_slab(wall_pos, Vector3(seg_len, WALL_HEIGHT, 1.0), wall_col, WALL_LAYER, 0.0, true, rot_y, WALL_DEPTH_BELOW_GROUND))

		var ring_pos := local_pos
		ring_pos.y = local_ground_y + 0.03   # avoid z-fighting with the ground
		_ring_pieces.append(_decor(ring_pos, Vector3(seg_len, 0.06, 0.4), glow_col, 1.0, rot_y))

## `pos` is local to stage_root (i.e. relative to the arena's own origin),
## not a world-space coordinate — callers must not fold in global_position.
## Returns the visual mesh specifically (not the StaticBody3D) so play_intro()
## can animate it without touching the collider at all.
## `collider_extra_depth` stretches just the collision shape straight down by
## that much (see WALL_DEPTH_BELOW_GROUND) without changing the visible mesh
## or its size/position at all — it's buried underground, so there's nothing
## to see either way.
func _slab(pos: Vector3, size: Vector3, col: Color, layer: int, emit: float, translucent := false, rot_y := 0.0, collider_extra_depth := 0.0) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = pos
	body.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0.0, collider_extra_depth, 0.0)
	cs.shape = shape
	cs.position.y = -collider_extra_depth * 0.5   # grow only downward; the top stays put
	body.add_child(cs)
	var mesh := _mesh(size, col, emit, translucent)
	body.add_child(mesh)
	stage_root.add_child(body)
	return mesh

func _decor(pos: Vector3, size: Vector3, col: Color, emit: float, rot_y := 0.0) -> MeshInstance3D:
	var m := _mesh(size, col, emit, false)
	m.position = pos
	m.rotation.y = rot_y
	stage_root.add_child(m)
	return m

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
