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
## What touching an orb actually does depends on the equipped weapon (see
## _on_orb_hit()/_spawn_orbs()) — Sword's plain combo hits, Bow's stack-then-
## release arrow/shoot pair, Staff's rune-buffer/spell system (queue runes,
## release them together with a CAST orb — see _lookup_spell()).
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
const LAND_HITSTOP_BASE := 0.07   ## seconds of freeze on a landing hit...
const LAND_HITSTOP_PER_HIT := 0.015   ## ...plus this per orb in the combo...
const LAND_HITSTOP_MAX := 0.22        ## ...up to this cap
const INTRO_DELAY := 1.0       ## enemies hold fire for this long after the reveal

## ---- weapon-specific orb behavior (see _on_orb_hit()/_spawn_orbs()) ----
const BOW_ARROW_WEIGHT := 0.6   ## vs. BOW_SHOOT_WEIGHT when randomly picking each orb's
const BOW_SHOOT_WEIGHT := 0.4   ## kind — weighted more toward arrows since a shoot orb
                                 ## spends the whole stack in one go
const STAFF_BURN_DPS := 3.0
const STAFF_SLOW_MULT := 0.5
## How long each element's status effect lasts once a spell applies it —
## shared by all of them for simplicity; split these out per-status if any
## one of them ever needs to be tuned independently.
const STAFF_STATUS_TIME := 3.0
const STAFF_STUN_TIME := 1.0   ## Earth's stun, applied by any cast spell that includes it
const STAFF_BUFFER_MAX := 3        ## queuing a 4th overloads the staff instead — see _overload_staff()
const STAFF_BUFFER_TIMEOUT := 4.0  ## seconds of not queueing a new rune before the buffer clears itself
const STAFF_OVERLOAD_DAMAGE := 15.0   ## self-inflicted, pierces shield (Player.hit()'s pierces_shield) —
                                        ## an overload is a mistake, not something a shield should soften
const STAFF_OVERLOAD_FLING_UP := 8.0     ## vertical pop from an overload — gentler than a real
const STAFF_OVERLOAD_FLING_PUSH := 5.0   ## wall bounce (PlayerConfig.wall_bounce_up/push), just enough
                                           ## to read as "that knocked me back" rather than a launch
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
var gold_reward := 0
var _arrow_stack := 0.0   ## Bow only — damage banked by ARROW orbs, released by the next SHOOT orb
var _rune_buffer: Array = []   ## Staff only — queued runes (Orb.Kind values), oldest first,
                                 ## released/cleared by the next CAST orb — see _lookup_spell()
var _rune_buffer_t := 0.0      ## counts down to 0 while _rune_buffer isn't empty; see _process()
var _sword_banked := 0.0   ## Sword only — damage from airborne orb hits, dealt when the player lands
var _buffer_label: Label3D     ## floats over the player showing the queued runes — Staff only,
                                 ## built in begin() and freed in _end()
var _spell_table: Dictionary = {}   ## built once in _ready() — see _build_spell_table()
var stage_root: Node3D   ## holds only the barrier wall, so WorldDissolver can
                          ## target it without touching enemies/orbs
var _over := false
var _wall_meshes: Array[MeshInstance3D] = []   ## one per wall segment — see play_intro()
var _ring_pieces: Array[MeshInstance3D] = []   ## one per ground-ring segment, same order/angle
                                                ## as _wall_meshes

static func radius_for(enemy_count: int) -> float:
	return minf(MAX_RADIUS, BASE_RADIUS + RADIUS_PER_ENEMY * maxi(0, enemy_count - 1))

func _ready() -> void:
	_build_spell_table()

## Ticks the rune buffer's own idle timeout — stalling too long after
## queueing a rune clears it, same spirit as a jump buffer/coyote window
## expiring, so Staff can't just be planned out indefinitely mid-fight.
func _process(delta: float) -> void:
	if _rune_buffer.is_empty():
		return
	_rune_buffer_t -= delta
	if _rune_buffer_t <= 0.0:
		_rune_buffer.clear()
		_update_buffer_label()

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
	if _equipped_weapon_kind() == WeaponData.Kind.STAFF:
		_buffer_label = Label3D.new()
		_buffer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_buffer_label.no_depth_test = true
		_buffer_label.position = Vector3(0, 2.3, 0)
		_buffer_label.visible = false
		p.add_child(_buffer_label)   # tracks the player automatically; freed in _end()
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
	var kinds := _orb_kinds_for_weapon(count)
	for i in count:
		var o := Orb.new()
		o.kind = kinds[i]   # before add_child() — _ready()'s _refresh() needs it to pick the right color
		add_child(o)
		var pos := _free_orb_position(targets)
		targets.append(pos)
		o.hit.connect(_on_orb_hit)
		orbs.append(o)
		o.drop_in(pos, ORB_DROP_HEIGHT, ORB_DROP_TIME, i * ORB_DROP_STAGGER)

## What kind each of `count` freshly-spawned orbs should be, picked purely by
## the currently equipped weapon — Sword spawns all plain orbs (today's
## original behavior), Bow spawns a weighted mix of arrow/shoot, Staff an
## even mix of the three elements. A relocated orb (see _on_orb_hit()'s
## respawn scheduling) keeps whatever kind it already had rather than
## re-rolling — simpler, and it means the overall mix this picks at the
## start of the fight roughly holds for its whole duration.
func _orb_kinds_for_weapon(count: int) -> Array:
	match _equipped_weapon_kind():
		WeaponData.Kind.BOW:
			return _random_kinds(count, [Orb.Kind.ARROW, Orb.Kind.SHOOT],
					[BOW_ARROW_WEIGHT, BOW_SHOOT_WEIGHT])
		WeaponData.Kind.STAFF:
			# Exactly one CAST orb per fight, regardless of size — multiple would
			# just mean never needing to wait for one, which flattens the whole
			# "queue runes, then commit" rhythm the buffer's built around. The
			# rest are an even mix of the three runes.
			var out := _random_kinds(maxi(0, count - 1),
					[Orb.Kind.FIRE, Orb.Kind.ICE, Orb.Kind.EARTH],
					[1.0, 1.0, 1.0])
			out.append(Orb.Kind.CAST)
			out.shuffle()
			return out
		_:
			var out: Array = []
			out.resize(count)
			out.fill(Orb.Kind.PLAIN)
			return out

func _equipped_weapon_kind() -> WeaponData.Kind:
	var w := Game.stats.equipped_weapon
	return w.kind if w else WeaponData.Kind.SWORD

func _random_kinds(count: int, kinds: Array, weights: Array) -> Array:
	var total := 0.0
	for w in weights: total += w
	var out: Array = []
	for _i in count:
		var roll := randf() * total
		var acc := 0.0
		for i in kinds.size():
			acc += weights[i]
			if roll <= acc:
				out.append(kinds[i])
				break
	return out

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

## Dispatches purely on the currently equipped weapon — each handler decides
## for itself what this particular orb touch does (deal damage, bank it,
## nothing at all) and, if it actually dealt damage, calls _resolve_hit() for
## the bookkeeping every damaging hit shares.
func _on_orb_hit(orb: Orb) -> void:
	if _over:
		return
	match _equipped_weapon_kind():
		WeaponData.Kind.BOW: _handle_bow_hit(orb)
		WeaponData.Kind.STAFF: _handle_staff_hit(orb)
		_: _handle_sword_hit(orb)

## Sword: an orb hit in the air only BANKS its damage (combo scaling still
## applies) and bounces you back up — no damage, no hitstop yet. Everything
## is dealt at once when the player touches the ground, see _land_sword_combo().
func _handle_sword_hit(orb: Orb) -> void:
	combo += 1
	var dmg := Game.stats.damage() * (1.0 + COMBO_BONUS * (combo - 1))
	_sword_banked += dmg
	player.bounce_off_orb(combo)
	Events.orb_hit.emit(combo, dmg)
	Events.combo_changed.emit(combo)
	_respawn_orb_later(orb)

## The landing: hit every enemy for the whole banked combo, with a freeze
## frame, a squash on each enemy, damage numbers and a screen kick.
func _land_sword_combo() -> void:
	var total := _sword_banked
	var hits := combo
	_sword_banked = 0.0
	var power := float(hits)
	for e in enemies.duplicate():
		if is_instance_valid(e):
			HitBurst.spawn(self, e.global_position + Vector3.UP * (0.8 * e.data.size), total, power)
			e.punch()
			e.take_damage(total)   # same damage to every enemy
	Events.combo_landed.emit(total, hits)
	if player.camera_rig:
		player.camera_rig.shake(minf(0.25 + 0.06 * hits, 0.8))
	HitStop.freeze(minf(LAND_HITSTOP_BASE + LAND_HITSTOP_PER_HIT * hits, LAND_HITSTOP_MAX))

## ARROW orbs bank damage without hitting anything; the next SHOOT orb
## releases the whole bank at once (and does nothing if nothing's banked —
## you still touched it, so it still respawns, just with no effect this time).
## Collecting an arrow doesn't bounce the player like a real hit does — it's
## just a pickup (see Orb.Kind's doc comment), not combat feedback.
func _handle_bow_hit(orb: Orb) -> void:
	if orb.kind == Orb.Kind.ARROW:
		_arrow_stack += Game.stats.damage()
		_respawn_orb_later(orb)
		return
	if _arrow_stack <= 0.0:
		player.bounce_off_orb(1)   # a whiff — nothing was stacked to release
		_respawn_orb_later(orb)
		return
	combo += 1
	var dmg := _arrow_stack
	_arrow_stack = 0.0
	_resolve_hit(orb, dmg, combo)

## A rune (FIRE/ICE/EARTH) just queues itself, no damage dealt and no bounce
## — it's a pickup, not combat feedback (see Orb.Kind's doc comment). CAST is
## the only orb that actually resolves anything. Queuing past STAFF_BUFFER_MAX
## doesn't quietly drop the oldest rune — it overloads instead, see
## _overload_staff().
func _handle_staff_hit(orb: Orb) -> void:
	if orb.kind == Orb.Kind.CAST:
		_cast_rune_buffer(orb)
		return
	if _rune_buffer.size() >= STAFF_BUFFER_MAX:
		_overload_staff(orb)
		return
	_rune_buffer.append(orb.kind)
	_rune_buffer_t = STAFF_BUFFER_TIMEOUT
	_update_buffer_label()
	_respawn_orb_later(orb)

## Queuing a 4th rune overloads the staff: the whole buffer dumps itself as
## self-inflicted damage (pierces the shield, same as a real hit that
## ignores it — see Player.hit()) with a tri-color burst (one per element,
## matching Orb.KIND_COLORS so it's visually the same "fire/ice/earth" the
## runes themselves use) and a small outward/upward fling so it still reads
## as a real hit, not just a number disappearing. The orb that triggered it
## still respawns normally.
func _overload_staff(orb: Orb) -> void:
	_rune_buffer.clear()
	_rune_buffer_t = 0.0
	_update_buffer_label()
	for element in [Orb.Kind.FIRE, Orb.Kind.ICE, Orb.Kind.EARTH]:
		VFX.shatter(self, player.global_position, Orb.KIND_COLORS[element][0], 1.3)
	player.hit(STAFF_OVERLOAD_DAMAGE, true)
	if not player.dead:
		var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		dir = dir.normalized() if dir.length() > 0.01 else -player.facing
		player.set_hvel(dir * STAFF_OVERLOAD_FLING_PUSH)
		player.velocity.y = STAFF_OVERLOAD_FLING_UP
		player.machine.transition_to(&"Air")
	_respawn_orb_later(orb)

## Looks up whatever's queued as a spell (see _lookup_spell()), applies its
## damage multiplier and status effects, then clears the buffer either way —
## a cast always consumes it, even on a combination with no table entry.
func _cast_rune_buffer(orb: Orb) -> void:
	if _rune_buffer.is_empty():
		player.bounce_off_orb(1)   # nothing queued — a whiff, same as Bow's empty shoot
		_respawn_orb_later(orb)
		return
	var spell: Dictionary = _lookup_spell(_rune_buffer)
	_rune_buffer.clear()
	_rune_buffer_t = 0.0
	_update_buffer_label()
	combo += 1
	var dmg := Game.stats.damage() * (spell.mult as float)
	for status in (spell.statuses as Array):
		_apply_element_status(status)
	_resolve_hit(orb, dmg, combo)

func _apply_element_status(element: Orb.Kind) -> void:
	for e in enemies:
		if not is_instance_valid(e):
			continue
		match element:
			Orb.Kind.FIRE: e.apply_burn(STAFF_BURN_DPS, STAFF_STATUS_TIME)
			Orb.Kind.ICE: e.apply_slow(STAFF_SLOW_MULT, STAFF_STATUS_TIME)
			Orb.Kind.EARTH: e.apply_stun(STAFF_STUN_TIME)

## Named combinations (order doesn't matter — a multiset lookup, so Fire+Ice
## and Ice+Fire are the same spell), each a {mult, statuses} pair: `mult`
## multiplies Game.stats.damage() same as a combo step would, `statuses` is
## every element whose effect the cast applies (a spell with two elements in
## its name applies both). Add a new spell by adding a new entry here — it
## needs nothing else touched, same as a new EquipmentLibrary item.
##
## Any combination NOT listed here (including any single rune not given its
## own entry) falls back to _fallback_spell(): never a dead end, just not as
## good as a combo you've actually learned — see _lookup_spell().
func _build_spell_table() -> void:
	_spell_table = {
		_rune_key([Orb.Kind.FIRE, Orb.Kind.FIRE]): {"mult": 2.4, "statuses": [Orb.Kind.FIRE]},
		_rune_key([Orb.Kind.ICE, Orb.Kind.ICE]): {"mult": 1.8, "statuses": [Orb.Kind.ICE]},
		_rune_key([Orb.Kind.EARTH, Orb.Kind.EARTH]): {"mult": 2.0, "statuses": [Orb.Kind.EARTH]},
		_rune_key([Orb.Kind.FIRE, Orb.Kind.ICE]): {"mult": 2.0, "statuses": [Orb.Kind.FIRE, Orb.Kind.ICE]},
		_rune_key([Orb.Kind.FIRE, Orb.Kind.EARTH]): {"mult": 2.0, "statuses": [Orb.Kind.FIRE, Orb.Kind.EARTH]},
		_rune_key([Orb.Kind.ICE, Orb.Kind.EARTH]): {"mult": 2.0, "statuses": [Orb.Kind.ICE, Orb.Kind.EARTH]},
		_rune_key([Orb.Kind.FIRE, Orb.Kind.ICE, Orb.Kind.EARTH]): {"mult": 3.5,
				"statuses": [Orb.Kind.FIRE, Orb.Kind.ICE, Orb.Kind.EARTH]},
	}

## `buffer`'s spell, from the table above if it's a combination that's been
## given one, otherwise a sensible default so casting anything is never
## wasted: one hit per queued rune's own worth of damage, with every element's
## status applied — i.e. exactly what a single Fire/Ice/Earth rune already
## does on its own below, just added up.
func _lookup_spell(buffer: Array) -> Dictionary:
	var key := _rune_key(buffer)
	if _spell_table.has(key):
		return _spell_table[key]
	return _fallback_spell(buffer)

func _fallback_spell(buffer: Array) -> Dictionary:
	var statuses: Array = []
	for rune in buffer:
		if rune not in statuses:
			statuses.append(rune)
	return {"mult": float(buffer.size()), "statuses": statuses}

## A canonical, order-independent key for a set of runes — Fire+Ice and
## Ice+Fire must look up the same table entry. Dictionary keys need to be
## hashable/comparable as a single value, not an array, hence joining into a
## string rather than using the sorted array itself as the key.
func _rune_key(buffer: Array) -> String:
	var sorted: Array = buffer.duplicate()
	sorted.sort()
	return ",".join(sorted.map(func(k): return str(k)))

func _update_buffer_label() -> void:
	if not _buffer_label:
		return
	if _rune_buffer.is_empty():
		_buffer_label.visible = false
		return
	_buffer_label.visible = true
	var parts: PackedStringArray = []
	for k in _rune_buffer:
		parts.append(_rune_name(k))
	_buffer_label.text = " + ".join(parts)

func _rune_name(k: Orb.Kind) -> String:
	match k:
		Orb.Kind.FIRE: return "Fire"
		Orb.Kind.ICE: return "Ice"
		Orb.Kind.EARTH: return "Earth"
		_: return "?"

## The part every damage-dealing orb hit shares, regardless of which weapon
## got it there: hit every enemy, bounce the player, fire the usual combo/
## orb_hit events, and schedule the orb's respawn.
func _resolve_hit(orb: Orb, dmg: float, combo_for_feedback: int) -> void:
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.take_damage(dmg)   # same damage to every enemy
	player.bounce_off_orb(combo_for_feedback)
	if _over:
		# That damage just finished off the last enemy — take_damage()'s
		# defeat chain ran synchronously inside the loop above and already
		# called _end(), which reset the combo to 0 for the HUD. Emitting
		# this hit's own (now-stale) nonzero combo below would stomp that
		# reset right back to the finishing count, and with the fight over
		# there's no later hit or landing left to clear it again — it would
		# just sit there on screen. Skip it instead.
		return
	Events.orb_hit.emit(combo_for_feedback, dmg)
	Events.combo_changed.emit(combo_for_feedback)
	_respawn_orb_later(orb)

func _respawn_orb_later(orb: Orb) -> void:
	get_tree().create_timer(ORB_RESPAWN_DELAY).timeout.connect(func():
		if is_instance_valid(orb) and not _over:
			var taken: Array[Vector3] = []
			for o in orbs:
				if is_instance_valid(o):
					taken.append(o.global_position)
			orb.relocate(_free_orb_position(taken)))

func _on_player_landed() -> void:
	if combo > 0:
		if _sword_banked > 0.0:
			_land_sword_combo()
		combo = 0
		if not _over:
			Events.combo_changed.emit(0)

func _on_enemy_defeated(e: Enemy) -> void:
	enemies.erase(e)
	gold_reward += e.data.gold
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
	_sword_banked = 0.0
	if _buffer_label:
		_buffer_label.queue_free()   # a child of player, not of this arena — won't go with it otherwise
	if victory:
		Game.stats.add_gold(gold_reward)
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
