class_name DialogueScript
extends RefCounted
## A whole NPC conversation parsed from a .dlg text file (see DialogueParser
## for the format): the entry DialogueNode plus the flag-switched alternatives.
## NPC asks `current()` each time you talk to it.

var entry: DialogueNode
## Alternatives, in file order — the first whose flag is set wins.
var variants: Array[DialogueVariant] = []
## Parse problems ("file:line: message"), also pushed to the editor's error log.
var errors: Array[String] = []

func current() -> DialogueNode:
	for v in variants:
		if v.dialogue != null and v.required_flag != &"" and Game.flag(v.required_flag):
			return v.dialogue
	return entry
