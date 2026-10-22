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
