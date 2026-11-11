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
## geometry animating (growing up, then sinking and popping away — see
## Arena.play_intro()/play_outro()), never a screen overlay or a change of
## location.

const MERGE_DISTANCE := 14.0
const POST_FIGHT_PAUSE := 0.8
const GRACE_TIME := 2.0         ## no new encounters right after one ends

var player: Player
var world_root: Node3D

var active_arena: Arena
var busy := false
var _grace := 0.0

func setup(p: Player, world: Node3D) -> void:
	player = p
	world_root = world

func register_world_enemy(e: WorldEnemy) -> void:
	e.touched.connect(_on_touched)

func _process(delta: float) -> void:
	_grace = maxf(0.0, _grace - delta)
	_unarmed_notice_left = maxf(0.0, _unarmed_notice_left - delta)

func _on_touched(enemy: WorldEnemy) -> void:
	if busy or _grace > 0.0 or player.dead:
		return
	if world_root != null and world_root.is_in_group(&"interior_level") \
			and not world_root.is_in_group(&"combat_allowed"):
		return   # no fights indoors, unless the level opts in (a dungeon)
	# The medium is decided here, once, and never changes mid-fight: a swimmer
	# fights fish, anyone else fights land enemies (see UnderwaterRules). An
	# enemy of the other medium just doesn't start a fight.
	var water := UnderwaterRules.swim_water(player)
	if (water != null) != enemy.data.aquatic:
		return
	if Game.stats.equipped_weapon == null:
		# Can't start a fight bare-handed: the enemy just hurts you instead.
		_warn_unarmed()
		enemy.strike_player(player)
		return
	var group: Array[WorldEnemy] = [enemy]
	for n in get_tree().get_nodes_in_group(&"world_enemies"):
		var other := n as WorldEnemy
		if other != enemy and other.is_awake() and other.data.aquatic == enemy.data.aquatic \
				and other.global_position.distance_to(enemy.global_position) <= MERGE_DISTANCE \
				and (water == null or WaterVolume.over(other.global_position) == water):
			group.append(other)
	var roster: Array[EnemyData] = []
	for w in group:
		roster.append(w.data)
	begin_encounter(roster, group, water)

const UNARMED_NOTICE_COOLDOWN := 8.0
var _unarmed_notice_left := 0.0

## Touching an enemy with no weapon equipped doesn't start a fight (it hurts
## instead, see WorldEnemy.strike_player()); say why now and then.
func _warn_unarmed() -> void:
	if _unarmed_notice_left > 0.0:
		return
	_unarmed_notice_left = UNARMED_NOTICE_COOLDOWN
	Events.notice.emit("You can't fight without a weapon.")

## Full encounter. `world_enemies` are the overworld enemies taking part (may be empty, e.g. debug).
## `water` is set for an underwater fight (the player is swimming in it): the
## arena is then a submerged dome on the seabed and the player keeps swimming.
func begin_encounter(roster: Array[EnemyData], world_enemies: Array[WorldEnemy] = [], water: WaterVolume = null) -> void:
	if busy:
		return
	busy = true
	Game.in_combat = true
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
	var origin := player.global_position
	if water != null:
		var seabed := UnderwaterRules.seabed_y(player, origin)
		origin.y = seabed if seabed > -INF else origin.y - 1.0   # the arena's floor is the seabed under the player
	arena.begin(player, origin, roster, water)
	await arena.play_intro()   # ground ring sweeps in, then the walls grow up (see Arena)
	player.machine.transition_to(&"Swim" if water != null else &"Ground")
	Game.input_locked = false
	arena.start_fight()

	# fight
	var victory: bool = await arena.finished
	Game.input_locked = true
	var cancelled := arena.cancelled
	if not cancelled:
		await get_tree().create_timer(POST_FIGHT_PAUSE, false).timeout

	await arena.play_outro()   # walls sink, ring dashes and posts pop out (see Arena)
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
	Game.in_combat = false
	busy = false
