class_name Door
extends Interactable
## A doorway into another level (a building interior, a cave, the outdoors
## again) — walk up, press interact, and Main swaps the current level out for
## `target_level`, placing the player at whichever Spawnpoint or DoorSpawn in
## it has `target_spawn_id` (see world/door_spawn.gd for the lightweight
## arrival-marker meant for interiors). The actual swap happens behind
## LoadingScreen's cartoon iris-pulse — see Main._on_level_travel_requested().
##
## Build it like any other Interactable (NPC, ShopKeeper): give it a
## CollisionShape3D for its physical body, so the player can't just walk
## through a closed door, plus whatever visual (a door model, a placeholder
## slab) as children. This script only owns what happens on interact.
##
## A level normally carries a Door back the other way too (an interior's own
## front door, pointing at the outdoor level's entrance Spawnpoint) — nobody
## tracks "which door did I come in through" globally; each Door is just
## statically configured with its own one-way destination, same as two
## regular doors in a real building both just leading somewhere.
##
## target_level is a PATH (res://.../whatever.tscn), not a PackedScene
## export, and deliberately so: an interior's own return door normally points
## back at the very outdoor level that placed the entrance Door leading to
## it, so the two .tscn files reference each other. A PackedScene export
## bakes that into an ext_resource — a real, eager dependency edge Godot
## resolves while PARSING the .tscn — so two such scenes form a genuine
## circular resource dependency and can deadlock loading each other (seen in
## practice: "Parse Error: Busy" the moment either one is opened). A plain
## path string carries no such edge; _interact() below loads it lazily, at
## the moment it's actually needed, by which point the other scene has
## already finished loading.
@export_file("*.tscn") var target_level: String
@export var target_spawn_id: StringName = &"start"

## Grounded and alive, same spirit as NPC's own gate — walking through a
## door mid-air/mid-roll/etc. would be a strange moment to cut away. Also
## refused while a swap is already underway (Game.input_locked, set for the
## swap's own duration — see Main), so a second press can't queue another
## one on top of it.
func _can_interact() -> bool:
	return not target_level.is_empty() and player != null and not player.dead \
		and player.machine.current_name == &"Ground" and not Game.input_locked \
		and not Game.in_combat

func _interact() -> void:
	Events.level_travel_requested.emit(load(target_level) as PackedScene, target_spawn_id)
