extends Node
## Global event bus. Systems talk through these signals so they stay decoupled.

# Combat
signal encounter_started(arena: Node)
signal encounter_ended(arena: Node, victory: bool)
signal encounter_returned(player_defeated: bool)   ## back in the overworld
signal orb_hit(combo: int, damage: float)
signal combo_changed(combo: int)
signal enemy_defeated(enemy: Node, xp: int)

# Player
signal player_damaged(hp: float, shield: float)
signal player_died
signal player_landed
signal stats_changed
signal leveled_up(level: int)

# World
signal spawnpoint_activated(id: StringName)
signal fast_travel_requested(id: StringName)
signal story_flag_changed(flag: StringName, value: Variant)
