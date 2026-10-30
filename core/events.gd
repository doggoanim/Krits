extends Node
## Global event bus. Systems talk through these signals so they stay decoupled.

# Combat
signal encounter_started(arena: Node)
signal encounter_ended(arena: Node, victory: bool)
signal encounter_returned(player_defeated: bool)   ## back in the overworld
signal orb_hit(combo: int, damage: float)
signal combo_changed(combo: int)
signal arrows_changed(count: int)   ## Bow: arrows currently stacked (0 = none) — the HUD shows this instead of the combo counter
signal runes_changed(runes: Array, lifetime: float)   ## Staff: the queued runes (Orb.Kind values, oldest first; empty = none) and how long the queue lasts — the HUD's RuneBar shows them
signal combo_landed(damage: float, hits: int, pound_bonus: bool)   ## the Sword's banked combo was just dealt on landing (pound_bonus: landed with a ground pound)
signal enemy_defeated(enemy: Node, gold: int)

# Inventory
signal notice(text: String)   ## a short message for the player (HUD toast)
signal item_gained(id: StringName, count: int)
signal inventory_full(id: StringName)   ## something didn't fit in the bag

# Player
signal rock_armor_changed(shield: float, max_shield: float)   ## the Earth spell's armor shield (0 = none) — HUD badge and the cubes on the player follow it
signal rock_armor_broken   ## the rock armor just broke (shield drained or recast) — shatter effects
signal player_damaged(hp: float, shield: float)
signal player_hurt(from: Vector3)   ## the player just took a hit (after i-frames); from = where it came from, or Vector3.INF
signal player_died
signal player_landed
signal stats_changed
signal stamina_denied   ## an ability was refused for lack of stamina — the HUD flashes the stamina bar
signal game_saved   ## a save was just written to disk — the SaveIndicator badge shows

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
