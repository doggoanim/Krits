class_name QuestLibrary
extends RefCounted
## Code-defined quest catalog (same spirit as ItemLibrary/AbilityLibrary).
## To add a quest: write a builder, list it in all_quests(), and add its
## texts to data/descriptions.cfg under [quests]:
##   <id>_title, <id>_desc, <id>_obj1, <id>_obj2 ...
## Hooking it into the world:
##   - start it: set its `start_flag` from a dialogue (DialogueNode/Choice
##     `sets_flag`) or leave the flag empty to be active from the start.
##   - FLAG objective: set that flag from dialogue.
##   - DEFEAT objective: the target is a WorldEnemy's `enemy_id`.
##   - REACH objective: place a QuestTrigger with that `place_id`.
##   - COLLECT objective: just an item id + amount.

## The main quest, part one: Mayor Arse sends you down Chesburg's well for water
## spirits, which you carry across the world to the desert town's mayor. The
## long road there is side content; this stays on the tracker until you arrive.
static func water_for_the_desert() -> QuestData:
	var q := _make(&"water_for_the_desert", true)
	q.objectives = [
		QuestObjective.make(QuestObjective.Kind.FLAG, &"water_quest_accepted"),
		QuestObjective.make(QuestObjective.Kind.COLLECT, &"water_spirits", 1, true),
		QuestObjective.make(QuestObjective.Kind.REACH, &"desert_town"),
		QuestObjective.make(QuestObjective.Kind.FLAG, &"delivered_water_spirits"),
	]
	q.reward_gold = 200
	_texts(q)
	return q

static func all_quests() -> Array[QuestData]:
	return [water_for_the_desert()]

static func by_id(id: StringName) -> QuestData:
	for q in all_quests():
		if q.id == id:
			return q
	return null

static func _make(id: StringName, main := false) -> QuestData:
	var q := QuestData.new()
	q.id = id
	q.is_main = main
	return q

## Fills title/description/objective text from descriptions.cfg.
static func _texts(q: QuestData) -> void:
	q.title = Descriptions.text("quests", StringName(String(q.id) + "_title"), String(q.id).capitalize())
	q.description = Descriptions.text("quests", StringName(String(q.id) + "_desc"))
	for i in q.objectives.size():
		q.objectives[i].text = Descriptions.text("quests", StringName("%s_obj%d" % [q.id, i + 1]))
