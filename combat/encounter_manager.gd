class_name EncounterManager
extends Node
## Runs the full encounter sequence:
##   touch -> a circular barrier rises right where the fight started (see
##   Arena.play_intro()) -> fight -> the barrier dissolves away again (or the
##   player respawns on defeat).
## Nearby overworld enemies are pulled into the same fight (bigger arena).
## Nobody goes anywhere: the player is never teleported, the camera never
## cuts away, and the world around the arena stays visible and unchanged —
## the barrier's reveal and its teardown are both just the barrier's own
## geometry animating (growing up, then crumbling into noise — see
## WorldDissolver for the teardown), never a screen overlay or a change of
## location.

const MERGE_DISTANCE := 14.0
const BARRIER_TIME := 0.7       ## how long the barrier takes to solidify/dissolve
const POST_FIGHT_PAUSE := 0.8
const GRACE_TIME := 2.0         ## no new encounters right after one ends

var player: Player
var world_root: Node3D

var active_arena: Arena
var busy := false
var _grace := 0.0
var _dissolver := WorldDissolver.new()

func setup(p: Player, world: Node3D) -> void:
	player = p
	world_root = world

func register_world_enemy(e: WorldEnemy) -> void:
	e.touched.connect(_on_touched)

func _process(delta: float) -> void:
	_grace = maxf(0.0, _grace - delta)

func _on_touched(enemy: WorldEnemy) -> void:
	if busy or _grace > 0.0 or player.dead:
		return
	var group: Array[WorldEnemy] = [enemy]
	for n in get_tree().get_nodes_in_group(&"world_enemies"):
		var other := n as WorldEnemy
		if other != enemy and other.is_awake() and \
				other.global_position.distance_to(enemy.global_position) <= MERGE_DISTANCE:
			group.append(other)
	var roster: Array[EnemyData] = []
	for w in group:
		roster.append(w.data)
	begin_encounter(roster, group)

## Full encounter. `world_enemies` are the overworld enemies taking part (may be empty, e.g. debug).
func begin_encounter(roster: Array[EnemyData], world_enemies: Array[WorldEnemy] = []) -> void:
	if busy:
		return
	busy = true
	Game.input_locked = true

	var origins := {}
	for w in world_enemies:
		origins[w] = w.global_position
	for n in get_tree().get_nodes_in_group(&"world_enemies"):
		(n as WorldEnemy).frozen = true
	player.enter_cinematic()   # brief hold while the barrier rises around them

	var arena := Arena.new()
	active_arena = arena
	get_parent().add_child(arena)
	arena.begin(player, player.global_position, roster)
	await arena.play_intro()   # ground ring sweeps in, then the walls grow up (see Arena)
	player.machine.transition_to(&"Ground")
	Game.input_locked = false
	arena.start_fight()

	# fight
	var victory: bool = await arena.finished
	Game.input_locked = true
	var cancelled := arena.cancelled
	if not cancelled:
		await get_tree().create_timer(POST_FIGHT_PAUSE).timeout

	_dissolver.begin(arena.stage_root)
	await _tween_progress(_dissolver, 1.0, BARRIER_TIME)
	# No .finish() here on purpose: that would restore the walls' original
	# (visible) material for a frame right before queue_free() takes effect.
	# Fully dissolved (progress 1.0) already discards every fragment, so the
	# barrier is already invisible — queue_free() can just take it from there.
	arena.queue_free()
	active_arena = null
	for w in world_enemies:
		if not is_instance_valid(w):
			continue
		if victory:
			w.defeat()
		else:
			w.global_position = origins[w]
			w.rotation.y = 0.0
	for n in get_tree().get_nodes_in_group(&"world_enemies"):
		(n as WorldEnemy).frozen = false

	var player_defeated := not victory and not cancelled
	Events.encounter_returned.emit(player_defeated)   # Main heals/respawns the player on defeat

	_grace = GRACE_TIME
	Game.input_locked = false
	busy = false

## Tweens a WorldDissolver's progress (0 = whole, 1 = fully dissolved) to `target`.
func _tween_progress(dissolver: WorldDissolver, target: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(dissolver.set_progress, dissolver.progress, target, duration)
	await tw.finished
