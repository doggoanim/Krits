class_name DialogueNode
extends Resource
## One line of a conversation. A full conversation is a graph of these built
## as nested sub-resources inside a single .tres (same authoring pattern as
## EnemyData/PlayerConfig) — not necessarily a straight chain or a tree,
## since a branch's `next` (or a DialogueChoice's own `next`) can point back
## to a node several paths share, letting branches rejoin a common
## continuation instead of each needing its own duplicate tail.
##
## Two ways a node moves forward, picked by whether `choices` is empty:
## - Empty: DialogueBox's own continue input goes straight to `next`.
##   `next == null` ends the conversation.
## - Non-empty: DialogueBox shows them as buttons instead of auto-advancing;
##   `next` is ignored in that case — see each DialogueChoice's own `next`.

@export var speaker: String = ""          ## the name label; "" for an unlabeled/narration line
@export_multiline var text: String = ""
@export var portrait: Texture2D           ## null hides the portrait for this line (not "keep the last one")

## Set true via Game.set_flag() (see core/game.gd) the moment this line is
## shown — for one-time story beats ("first time this NPC says X") without
## needing a separate script.
@export var sets_flag: StringName = &""

@export var next: DialogueNode            ## used only when choices is empty
@export var choices: Array[DialogueChoice] = []

## ---- Authoring helpers (for code-made lines; .tres files work as before) ----

## A one-off line, e.g. DialogueBox.instance.start(DialogueNode.say("Mira", "Hi!")).
static func say(speaker_name: String, line: String, then: DialogueNode = null) -> DialogueNode:
	var n := DialogueNode.new()
	n.speaker = speaker_name
	n.text = line
	n.next = then
	return n

## Builds a straight chain of lines from [[speaker, text], ...] and returns
## the first one. Quick way to script a short exchange in code.
static func chain(lines: Array) -> DialogueNode:
	var head: DialogueNode = null
	for i in range(lines.size() - 1, -1, -1):
		head = say(lines[i][0], lines[i][1], head)
	return head

## True if this line offers at least one currently-visible choice.
func visible_choices() -> Array[DialogueChoice]:
	var out: Array[DialogueChoice] = []
	for c in choices:
		if c != null and c.is_visible():
			out.append(c)
	return out

