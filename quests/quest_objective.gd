class_name QuestObjective
extends Resource
## One step of a quest. Every kind but COLLECT is just "has this story flag
## been set?", so objectives are cheap to hook up anywhere in the world:
##   FLAG    — Game.flag(target). Set by a dialogue line/choice (`sets_flag`),
##             a boss, a cutscene — anything. Use this for "talk to X".
##   DEFEAT  — the overworld enemy whose `enemy_id` is `target` was beaten
##             (its `cleared_<id>` flag, see WorldEnemy).
##   REACH   — the player entered the QuestTrigger whose `place_id` is `target`
##             (its `reached_<id>` flag).
##   COLLECT — the bag holds `amount` of item `target` (consumed on quest
##             completion when `consume` is set).
## Display text lives in data/descriptions.cfg ([quests] <quest>_obj<n>).

enum Kind { FLAG, DEFEAT, REACH, COLLECT }

@export var kind: Kind = Kind.FLAG
@export var target: StringName = &""
@export var amount := 1          ## COLLECT only
@export var consume := false     ## COLLECT only: take the items when the quest completes
@export var text := ""           ## shown in the tracker; filled from descriptions.cfg

static func make(k: Kind, tgt: StringName, amt := 1, consume_items := false) -> QuestObjective:
	var o := QuestObjective.new()
	o.kind = k
	o.target = tgt
	o.amount = amt
	o.consume = consume_items
	return o

## How far along this objective is, as {"have": n, "need": n}.
func progress() -> Dictionary:
	match kind:
		Kind.FLAG:
			return {"have": 1 if Game.flag(target) else 0, "need": 1}
		Kind.DEFEAT:
			return {"have": 1 if Game.flag(StringName("cleared_" + String(target))) else 0, "need": 1}
		Kind.REACH:
			return {"have": 1 if Game.flag(StringName("reached_" + String(target))) else 0, "need": 1}
		Kind.COLLECT:
			return {"have": mini(Game.inventory.count_of(target), amount), "need": amount}
	return {"have": 0, "need": 1}

func is_done() -> bool:
	var p := progress()
	return int(p["have"]) >= int(p["need"])
