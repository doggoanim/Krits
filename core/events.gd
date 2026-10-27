extends Node
## Global event bus. Systems talk through these signals so they stay decoupled.

# Combat
signal encounter_started(arena: Node)
signal encounter_ended(arena: Node, victory: bool)
signal encounter_returned(player_defeated: bool)   ## back in the overworld
signal orb_hit(combo: int, damage: float)
signal combo_changed(combo: int)
signal enemy_defeated(enemy: Node, gold: int)

# Player
signal player_damaged(hp: float, shield: float)
signal player_died
signal player_landed
signal stats_changed

# World
signal spawnpoint_activated(id: StringName)
signal fast_travel_requested(id: StringName)
signal story_flag_changed(flag: StringName, value: Variant)
## A Door was used — Main swaps the active level for `level_scene` and places
## the player at whichever Spawnpoint/DoorSpawn inside it has `spawn_id`,
## behind LoadingScreen's cartoon iris-pulse. See world/door.gd.
signal level_travel_requested(level_scene: PackedScene, spawn_id: StringName)

# Dialogue
signal dialogue_started
signal dialogue_ended
