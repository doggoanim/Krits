class_name DialogueVariant
extends Resource
## An alternative conversation an NPC says once a story flag is set — e.g. a
## quest giver's "welcome back" lines after the quest was accepted. NPC walks
## its `variants` in order and uses the first whose flag is set, falling back
## to its default `dialogue`. Put the most advanced state first.

@export var required_flag: StringName = &""
@export var dialogue: DialogueNode
