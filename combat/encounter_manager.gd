class_name EncounterManager
extends Node
## Runs the full encounter sequence:
##   touch -> everyone floats -> one crossfade (world dissolves out, stage dissolves
##   in) -> fight -> the reverse crossfade back to the world map (or respawn on defeat).
## Nearby overworld enemies are pulled into the same fight (bigger arena).
## "Dissolving" means the actual level/stage geometry crumbles into noise and
## reforms (see WorldDissolver) — there is no screen overlay involved. The fade-out
## and fade-in are two halves of one timed beat (see CROSSFADE_TIME), not two
## separate full-length dissolves played back to back.

const MERGE_DISTANCE := 14.0
const STAGE_ORIGIN := Vector3(0.0, 400.0, 0.0)   ## stage floats high above the world
const FLOAT_HEIGHT := 2.2
const FLOAT_TIME := 0.9
const CROSSFADE_TIME := 0.9   ## total time for world-out+stage-in as ONE beat (each half gets CROSSFADE_TIME * 0.5)
const POST_FIGHT_PAUSE := 0.8
const GRACE_TIME := 2.0                           ## no new encounters right after returning

var player: Player
var world_root: Node3D
var environment: Environment

var active_arena: Arena
var busy := false
var _grace := 0.0
var _saved_env := {}
var _world_dissolver := WorldDissolver.new()
var _arena_dissolver := WorldDissolver.new()

func setup(p: Player, world: Node3D, env: Environment) -> void:
	player = p
	world_root = world
	environment = env

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

	var origin_pos := player.global_position
	var origins := {}
	for w in world_enemies:
		origins[w] = w.global_position
	for n in get_tree().get_nodes_in_group(&"world_enemies"):
		(n as WorldEnemy).frozen = true
	player.enter_cinematic()

	# 1) float
	if not world_enemies.is_empty():
		await _float(world_enemies)

	# 2) one crossfade, not two separate full dissolves: the world fades out and,
	# the instant it's gone, the stage fades in to take its place. Each half gets
	# half the time, so the whole beat reads as a single continuous transition.
	var half := CROSSFADE_TIME * 0.5
	_world_dissolver.begin(world_root)
	await _tween_progress(_world_dissolver, 1.0, half)
	world_root.visible = false
	_set_stage_environment(true)

	var arena := Arena.new()
	active_arena = arena
	get_parent().add_child(arena)
	arena.begin(player, STAGE_ORIGIN, roster)
	_arena_dissolver.begin(arena.stage_root)
	_arena_dissolver.set_progress(1.0)
	await _tween_progress(_arena_dissolver, 0.0, half)
	_arena_dissolver.finish()
	Game.input_locked = false
	arena.start_fight()

	# 3) fight
	var victory: bool = await arena.finished
	Game.input_locked = true
	var cancelled := arena.cancelled
	if not cancelled:
		await get_tree().create_timer(POST_FIGHT_PAUSE).timeout

	# 4) the reverse crossfade: stage fades out, then world fades back in
	_arena_dissolver.begin(arena.stage_root)
	await _tween_progress(_arena_dissolver, 1.0, half)
	arena.queue_free()
	active_arena = null
	_set_stage_environment(false)
	world_root.visible = true
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
	if not player_defeated:
		player.teleport(origin_pos)
		player.camera_rig.snap()
	Events.encounter_returned.emit(player_defeated)   # Main respawns the player on defeat

	await _tween_progress(_world_dissolver, 0.0, half)
	_world_dissolver.finish()

	_grace = GRACE_TIME
	Game.input_locked = false
	busy = false

func _float(enemies: Array[WorldEnemy]) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "global_position:y", player.global_position.y + FLOAT_HEIGHT, FLOAT_TIME)
	tw.tween_property(player.visual, "rotation:y", player.visual.rotation.y + TAU, FLOAT_TIME)
	for e in enemies:
		tw.tween_property(e, "global_position:y", e.global_position.y + FLOAT_HEIGHT, FLOAT_TIME)
		tw.tween_property(e, "rotation:y", e.rotation.y + TAU, FLOAT_TIME)
	await tw.finished

## Tweens a WorldDissolver's progress (0 = whole, 1 = fully dissolved) to `target`.
func _tween_progress(dissolver: WorldDissolver, target: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(dissolver.set_progress, dissolver.progress, target, duration)
	await tw.finished

func _set_stage_environment(on: bool) -> void:
	if environment == null:
		return
	if on:
		_saved_env = {
			"mode": environment.background_mode,
			"src": environment.ambient_light_source,
			"col": environment.ambient_light_color,
			"energy": environment.ambient_light_energy,
		}
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.03, 0.04, 0.09)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.5, 0.6, 0.9)
		environment.ambient_light_energy = 0.7
	elif not _saved_env.is_empty():
		environment.background_mode = _saved_env["mode"]
		environment.ambient_light_source = _saved_env["src"]
		environment.ambient_light_color = _saved_env["col"]
		environment.ambient_light_energy = _saved_env["energy"]
