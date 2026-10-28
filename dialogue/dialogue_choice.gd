class_name DialogueChoice
extends Resource
## One player-pickable response inside a DialogueNode's `choices` list — see
## DialogueNode for how a full conversation fits together.

@export_multiline var text: String = ""   ## shown on the choice's button
@export var next: DialogueNode            ## where picking this leads; null ends the conversation

## Lets a choice be conditional (e.g. only offered once a quest flag is set)
## and/or carry its own side effect, independent of whatever DialogueNode.sets_flag
## the line it's attached to already does — both read through Game's existing
## story-flag system (see core/game.gd), the same one WorldGate etc. already use.
@export var required_flag: StringName = &""   ## hidden unless Game.flag(required_flag) is true; "" = always shown
@export var sets_flag: StringName = &""       ## set true via Game.set_flag() when this choice is picked; "" = no-op

@export var required_item: StringName = &""   ## hidden unless the bag holds this item

func is_visible() -> bool:
	return (required_flag == &"" or Game.flag(required_flag)) \
		and (required_item == &"" or Game.inventory.has(required_item))
