class_name QuestLog
extends RefCounted
## Which quests are done, and the live re-check that completes them. Owned by
## Game (Game.quests, saved with the slot). Only *completed* quests are stored:
## whether a quest is active, and how far along it is, is always derived from
## story flags and the bag (see QuestObjective), so nothing can drift out of
## sync. evaluate() re-checks everything whenever a flag or the bag changes.

var completed: Array[StringName] = []

var _evaluating := false
var _snapshot := ""      ## what the quest list looked like at the last evaluate()
var _primed := false     ## false right after a load / new game: the first look is silent

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
	var finished_any := false
	var again := true
	while again:
		again = false
		for q in active_quests():
			if not q.objectives.is_empty() and q.all_done():
				_complete(q)
				finished_any = true
				again = true
	_evaluating = false
	var now := _snapshot_now()
	# A finished quest already announced itself ("Quest complete: ..."); anything
	# else that changed the log (a quest unlocked, an objective advanced) gets the
	# generic toast. Never right after a load or new game.
	if _primed and now != _snapshot and not finished_any:
		Events.notice.emit("Quest log updated")
	_snapshot = now
	_primed = true
	Events.quests_changed.emit()

## Forgets what was last seen, so the next evaluate() starts quietly (a freshly
## loaded or reset save must not announce its existing quests as news).
func reset_baseline() -> void:
	_primed = false

## A comparable summary of the log: every active quest with its objectives'
## progress, plus how many are finished.
func _snapshot_now() -> String:
	var parts: PackedStringArray = [str(completed.size())]
	for q in active_quests():
		var bits: PackedStringArray = [String(q.id)]
		for o in q.objectives:
			bits.append(str(o.progress()["have"]))
		parts.append(":".join(bits))
	return "|".join(parts)

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
	reset_baseline()
	for raw in d.get("completed", []):
		completed.append(StringName(raw))
