class_name Hotbar
extends RefCounted
## The six hotbar slots plus the abilities the player knows. Slots 1-3
## (index 0-2) hold abilities, slots 4-6 (index 3-5) hold consumables (by
## item id — the item is taken from the bag when used). Lives on Game.hotbar,
## saved per slot. Keys 1-6 trigger them (see HotbarBar).

signal changed

const SLOT_COUNT := 6
const ABILITY_SLOTS := 3   ## slots 0..2 are abilities, 3..5 consumables

var slots: Array[StringName] = [&"", &"", &"", &"", &"", &""]
var known: Array[StringName] = []
var cooldowns := {}   ## ability id -> seconds left

func _init() -> void:
	for a in AbilityLibrary.starting():
		known.append(a.id)
	slots[0] = &"heal"
	slots[1] = &"super_jump"

static func is_ability_slot(index: int) -> bool:
	return index < ABILITY_SLOTS

func knows(id: StringName) -> bool:
	return id in known

func learn(id: StringName) -> void:
	if AbilityLibrary.by_id(id) != null and not knows(id):
		known.append(id)
		changed.emit()

func slot_of(id: StringName) -> int:
	return slots.find(id)

## Puts `id` on `slot` (moving it if it was on another slot). False if that
## slot can't hold it (ability on a consumable slot, unknown ability...).
func assign(slot: int, id: StringName) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	if is_ability_slot(slot):
		if not knows(id):
			return false
	else:
		var item := ItemLibrary.by_id(id)
		if item == null or not item.is_usable():
			return false
	var old := slots.find(id)
	if old != -1:
		slots[old] = &""
	slots[slot] = id
	changed.emit()
	return true

func clear(slot: int) -> void:
	if slot >= 0 and slot < SLOT_COUNT and slots[slot] != &"":
		slots[slot] = &""
		changed.emit()

func tick(delta: float) -> void:
	for id in cooldowns.keys():
		cooldowns[id] -= delta
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)

func cooldown_left(id: StringName) -> float:
	return cooldowns.get(id, 0.0)

## 0 = ready, 1 = just used.
func cooldown_fraction(id: StringName) -> float:
	var a := AbilityLibrary.by_id(id)
	if a == null or a.cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_left(id) / a.cooldown, 0.0, 1.0)

## Triggers hotbar slot `index`. Shows a short notice (Events.notice) when
## there's something to tell the player; returns true if something was used.
func use_slot(index: int, player: Player) -> bool:
	if index < 0 or index >= SLOT_COUNT or slots[index] == &"":
		return false
	var id := slots[index]
	if is_ability_slot(index):
		var ability := AbilityLibrary.by_id(id)
		if ability == null:
			return false
		if cooldown_left(id) > 0.0:
			Events.notice.emit("%s: %.0fs" % [ability.display_name, ceilf(cooldown_left(id))])
			return false
		if not Game.stats.can_afford(ability.stamina_cost):
			Events.notice.emit("Not enough stamina.")
			Events.stamina_denied.emit()
			return false
		var problem := AbilityRunner.activate(ability, player, Engine.get_main_loop() as SceneTree)
		if problem != "":
			Events.notice.emit(problem)
			return false
		Game.stats.spend_stamina(ability.stamina_cost)
		cooldowns[id] = ability.cooldown
		Events.notice.emit("%s!" % ability.display_name)
		return true
	var msg := Game.inventory.use_id(id)
	if msg != "":
		Events.notice.emit(msg)
	return msg.begins_with("Used")

func to_dict() -> Dictionary:
	return {
		"slots": slots.map(func(s): return String(s)),
		"known": known.map(func(s): return String(s)),
	}

func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return   # an old save with no hotbar: keep the starting loadout
	known.clear()
	for raw_id in d.get("known", []):
		var id := LegacyIds.fix(StringName(raw_id))
		if AbilityLibrary.by_id(id) != null:
			known.append(id)
	var raw: Array = d.get("slots", [])
	for i in SLOT_COUNT:
		slots[i] = LegacyIds.fix(StringName(raw[i])) if i < raw.size() else &""
	changed.emit()
