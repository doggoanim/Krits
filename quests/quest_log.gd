class_name QuestLog
extends RefCounted
## Which quests are done, and the live re-check that completes them. Owned by
## Game (Game.quests, saved with the slot). Only *completed* quests are stored:
## whether a quest is active, and how far along it is, is always derived from
## story flags and the bag (see QuestObjective), so nothing can drift out of
## sync. evaluate() re-checks everything whenever a flag or the bag changes.

var completed: Array[StringName] = []

var _evaluating := false

func connect_signals() -> void:
	Events.story_flag_changed.connect(func(_f: StringName, _v: Variant) -> void: evaluate())
	Events.item_gained.connect(func(_id: StringName, _n: int) -> void: evaluate())
	Events.stats_changed.connect(evaluate)

func is_complete(id: StringName) -> bool:
	return id in completed

## Active = unlocked (start flag set, required quest done) and not finished.
func is_active(q: QuestData) -> bool:
	if is_complete(q.id):
		return false
	if q.start_flag != &"" and not Game.flag(q.start_flag):
		return false
	if q.requires_quest != &"" and not is_complete(q.requires_quest):
		return false
	return true

## Active quests, main quest(s) first.
func active_quests() -> Array[QuestData]:
	var main: Array[QuestData] = []
	var side: Array[QuestData] = []
	for q in QuestLibrary.all_quests():
		if is_active(q):
			(main if q.is_main else side).append(q)
	return main + side

func completed_quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	for id in completed:
		var q := QuestLibrary.by_id(id)
		if q != null:
			out.append(q)
	return out

## Completes every active quest whose objectives are all done (repeating,
## since finishing one can unlock another), and tells the HUD to refresh.
func evaluate() -> void:
	if _evaluating:
		return
	_evaluating = true
	var again := true
	while again:
		again = false
		for q in active_quests():
			if not q.objectives.is_empty() and q.all_done():
				_complete(q)
				again = true
	_evaluating = false
	Events.quests_changed.emit()

func _complete(q: QuestData) -> void:
	completed.append(q.id)
	for o in q.objectives:
		if o.kind == QuestObjective.Kind.COLLECT and o.consume:
			Game.inventory.remove(o.target, o.amount)
	if q.reward_gold > 0:
		Game.stats.add_gold(q.reward_gold)
	for item_id: StringName in q.reward_items:
		Game.inventory.add(item_id, int(q.reward_items[item_id]))
	Game.set_flag(StringName("quest_done_" + String(q.id)))   # for follow-up gates/dialogue
	Events.notice.emit("Quest complete: %s" % q.title)
	Events.quest_completed.emit(q.id)

func to_dict() -> Dictionary:
	return {"completed": completed.map(func(id: StringName) -> String: return String(id))}

func from_dict(d: Dictionary) -> void:
	completed.clear()
	for raw in d.get("completed", []):
		completed.append(StringName(raw))
