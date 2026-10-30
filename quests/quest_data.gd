class_name QuestData
extends Resource
## A quest: ordered objectives, optional rewards, and the conditions for it to
## appear. Built by QuestLibrary; tracked by QuestLog. Main quests are listed
## first in the tracker.

@export var id: StringName = &""
@export var title := ""
@export_multiline var description := ""
@export var is_main := false
## The quest becomes active when this story flag is set (a dialogue `sets_flag`,
## a trigger...). Empty = active from the start of the game.
@export var start_flag: StringName = &""
## Optional: also needs this other quest completed first.
@export var requires_quest: StringName = &""
@export var objectives: Array[QuestObjective] = []
@export var reward_gold := 0
@export var reward_items := {}   ## item id (StringName) -> count

## The first objective not done yet (null when all are done).
func current_objective() -> QuestObjective:
	for o in objectives:
		if not o.is_done():
			return o
	return null

func all_done() -> bool:
	for o in objectives:
		if not o.is_done():
			return false
	return true
