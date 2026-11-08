class_name WellEntrance
extends Interactable
## The hollow middle of a well: once `required_flag` is set (the quest that
## sends the player down), walking up shows a prompt and interacting drops
## them into another level (see Door for the mechanics of a level swap).
## Unlike Door it has no physical body to build — the well's own model/props
## provide the collision; this node is just the prompt anchor, so place it
## over the well's opening and tune `interact_radius`.

@export_file("*.tscn") var target_level: String
@export var target_spawn_id: StringName = &"well_drop"
## Story flag that unlocks the well. Empty = always usable.
@export var required_flag: StringName = &"water_quest_accepted"

func _can_interact() -> bool:
	if target_level.is_empty() or player == null or player.dead:
		return false
	if not required_flag.is_empty() and not Game.flag(required_flag):
		return false
	return player.machine.current_name == &"Ground" and not Game.input_locked \
		and not Game.in_combat

func _interact() -> void:
	Events.level_travel_requested.emit(load(target_level) as PackedScene, target_spawn_id)
