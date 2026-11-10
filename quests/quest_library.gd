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
	q.start_flag = &"water_quest_accepted"   # nothing in the log until Mayor Arse gives it
	q.objectives = [
		QuestObjective.make(QuestObjective.Kind.FLAG, &"water_quest_accepted"),
		QuestObjective.make(QuestObjective.Kind.COLLECT, &"water_spirits", 1, true),
		QuestObjective.make(QuestObjective.Kind.REACH, &"desert_town"),
		QuestObjective.make(QuestObjective.Kind.FLAG, &"delivered_water_spirits"),
	]
	q.reward_gold = 200
	_texts(q)
	return q

## Side quest: Yule lost a ball down the well. Find it, bring it back.
static func yules_ball() -> QuestData:
	var q := _make(&"yules_ball")
	q.start_flag = &"yule_quest_accepted"
	q.objectives = [
		QuestObjective.make(QuestObjective.Kind.FLAG, &"yule_quest_accepted"),
		QuestObjective.make(QuestObjective.Kind.COLLECT, &"yule_ball", 1, true),
		QuestObjective.make(QuestObjective.Kind.FLAG, &"yule_got_ball"),
	]
	q.reward_gold = 60
	q.reward_items = {&"health_potion": 2}
	_texts(q)
	return q

## Side quest: Marta the baker needs three slime goo from the slimes out by the hilltop.
static func goo_for_marta() -> QuestData:
	var q := _make(&"goo_for_marta")
	q.start_flag = &"marta_quest_accepted"
	q.objectives = [
		QuestObjective.make(QuestObjective.Kind.FLAG, &"marta_quest_accepted"),
		QuestObjective.make(QuestObjective.Kind.COLLECT, &"slime_goo", 3, true),
		QuestObjective.make(QuestObjective.Kind.FLAG, &"marta_got_goo"),
	]
	q.reward_gold = 80
	q.reward_items = {&"shield_restore": 1}
	_texts(q)
	return q

## Side quest: Brant's pack is stuck on a high ledge outside town. Long-jump the
## gap, climb the wall, bring it back (the parkour route is the "OvergrownLedges" prop in chesburg.tscn).
static func overgrown_ledges() -> QuestData:
	var q := _make(&"overgrown_ledges")
	q.start_flag = &"brant_quest_accepted"
	q.objectives = [
		QuestObjective.make(QuestObjective.Kind.FLAG, &"brant_quest_accepted"),
		QuestObjective.make(QuestObjective.Kind.COLLECT, &"hiker_pack", 1, true),
		QuestObjective.make(QuestObjective.Kind.FLAG, &"brant_got_pack"),
	]
	q.reward_gold = 100
	q.reward_items = {&"health_potion": 2}
	_texts(q)
	return q

static func all_quests() -> Array[QuestData]:
	return [water_for_the_desert(), yules_ball(), goo_for_marta(), overgrown_ledges()]

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
