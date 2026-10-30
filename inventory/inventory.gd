class_name Inventory
extends RefCounted
## The player's bag: a limited number of slots, each holding a stack of one
## item. Capacity = BASE_SLOTS + the best backpack owned. Lives on
## Game.inventory and is saved with the slot (to_dict/from_dict).
## Equipment is not stored here — see PlayerStats' owned_*/equipped_*.

signal changed

const BASE_SLOTS := 10

## Each entry: {"id": StringName, "count": int}. Compact (no empty gaps) and
## kept in the order items arrived.
var stacks: Array[Dictionary] = []
var backpack_id: StringName = &""
## Key items (ItemData.Category.KEY) live apart from the bag: they take no slots,
## never count toward capacity and can't be sold or dropped. id -> count.
var key_items: Dictionary = {}

func capacity() -> int:
	var bag := ItemLibrary.backpack_by_id(backpack_id)
	return BASE_SLOTS + (bag.slots if bag else 0)

func backpack() -> BackpackData:
	return ItemLibrary.backpack_by_id(backpack_id)

func count_of(id: StringName) -> int:
	var total: int = int(key_items.get(id, 0))
	for s in stacks:
		if s["id"] == id:
			total += s["count"]
	return total

func has(id: StringName, amount := 1) -> bool:
	return count_of(id) >= amount

func free_slots() -> int:
	return capacity() - stacks.size()

## Adds up to `amount` of `id`; returns how many did NOT fit (0 = all stored).
func add(id: StringName, amount := 1) -> int:
	var item := ItemLibrary.by_id(id)
	if item == null or amount <= 0:
		return amount
	if item.category == ItemData.Category.KEY:
		key_items[id] = mini(int(key_items.get(id, 0)) + amount, maxi(item.max_stack, 1))
		Events.item_gained.emit(id, amount)
		changed.emit()
		return 0
	var left := amount
	for s in stacks:
		if left == 0:
			break
		if s["id"] == id and s["count"] < item.max_stack:
			var put := mini(left, item.max_stack - s["count"])
			s["count"] += put
			left -= put
	while left > 0 and stacks.size() < capacity():
		var put := mini(left, item.max_stack)
		stacks.append({"id": id, "count": put})
		left -= put
	var stored := amount - left
	if stored > 0:
		Events.item_gained.emit(id, stored)
		changed.emit()
	if left > 0:
		Events.inventory_full.emit(id)
	return left

## True if `amount` of `id` would fit right now (room in existing stacks +
## empty slots).
func can_fit(id: StringName, amount := 1) -> bool:
	var item := ItemLibrary.by_id(id)
	if item == null:
		return false
	if item.category == ItemData.Category.KEY:
		return true   # key items take no bag space
	var room := free_slots() * item.max_stack
	for s in stacks:
		if s["id"] == id:
			room += item.max_stack - s["count"]
	return room >= amount

## Shop: buys one `item` if it's for sale, affordable and fits.
func buy_item(item: ItemData) -> bool:
	if item.buy_price <= 0 or item.buy_price > Game.stats.gold or not can_fit(item.id, 1):
		return false
	Game.stats.gold -= item.buy_price
	add(item.id, 1)
	Events.stats_changed.emit()
	return true

## Shop: sells up to `amount` of `id` at its sell price; returns gold earned.
func sell_item(id: StringName, amount := 1) -> int:
	var item := ItemLibrary.by_id(id)
	if item == null or item.sell_price <= 0 or item.category == ItemData.Category.KEY:
		return 0
	var n := mini(amount, count_of(id))
	if n <= 0 or not remove(id, n):
		return 0
	var earned := n * item.sell_price
	Game.stats.add_gold(earned)
	return earned

## Removes up to `amount` from stack `index`; returns how many were removed.
func remove_at(index: int, amount := 1) -> int:
	if index < 0 or index >= stacks.size():
		return 0
	var take := mini(amount, stacks[index]["count"])
	stacks[index]["count"] -= take
	if stacks[index]["count"] <= 0:
		stacks.remove_at(index)
	changed.emit()
	return take

## Removes `amount` of `id` from wherever it is (false, and nothing removed,
## if there isn't that much).
func remove(id: StringName, amount := 1) -> bool:
	if not has(id, amount):
		return false
	var left := amount
	if key_items.has(id):   # only quests consume key items (QuestObjective.consume)
		var take := mini(left, int(key_items[id]))
		key_items[id] = int(key_items[id]) - take
		if int(key_items[id]) <= 0:
			key_items.erase(id)
		left -= take
		changed.emit()
	var i := stacks.size() - 1
	while i >= 0 and left > 0:
		if stacks[i]["id"] == id:
			left -= remove_at(i, left)
		i -= 1
	return true

## Uses one item from stack `index`. Returns a short message (empty = nothing
## happened, e.g. not usable / already at full health).
func use(index: int) -> String:
	if index < 0 or index >= stacks.size():
		return ""
	var item := ItemLibrary.by_id(stacks[index]["id"])
	if item == null or not item.is_usable():
		return ""
	var stats := Game.stats
	var needs_hp := item.heal_hp > 0.0 and stats.hp < stats.max_hp()
	var needs_shield := item.heal_shield > 0.0 and stats.shield < stats.max_shield()
	if not needs_hp and not needs_shield:
		return "Nothing to restore right now."
	stats.heal(item.heal_hp, item.heal_shield)
	remove_at(index, 1)
	return "Used %s." % item.display_name

## Uses the first stack of `id` (used by the hotbar). "" if you have none.
func use_id(id: StringName) -> String:
	for i in stacks.size():
		if stacks[i]["id"] == id:
			return use(i)
	return "You're out of those."

## Buys `bag` if it's an upgrade you can afford. False = nothing changed.
func buy_backpack(bag: BackpackData) -> bool:
	if bag.slots <= (backpack().slots if backpack() else 0) or bag.price > Game.stats.gold:
		return false
	Game.stats.gold -= bag.price
	backpack_id = bag.id
	Events.stats_changed.emit()
	changed.emit()
	return true

func to_dict() -> Dictionary:
	return {
		"backpack": String(backpack_id),
		"stacks": stacks.map(func(s): return {"id": String(s["id"]), "count": s["count"]}),
		"key_items": key_items.keys().map(func(k): return {"id": String(k), "count": int(key_items[k])}),
	}

func from_dict(d: Dictionary) -> void:
	stacks.clear()
	key_items.clear()
	backpack_id = StringName(d.get("backpack", ""))
	for raw in d.get("stacks", []):
		var id := LegacyIds.fix(StringName(raw.get("id", "")))
		var item := ItemLibrary.by_id(id)
		if item == null:
			continue
		if item.category == ItemData.Category.KEY:   # an older save kept keys in the bag
			key_items[id] = int(key_items.get(id, 0)) + int(raw.get("count", 1))
		elif stacks.size() < capacity():
			stacks.append({"id": id, "count": int(raw.get("count", 1))})
	for raw in d.get("key_items", []):
		var id := LegacyIds.fix(StringName(raw.get("id", "")))
		if ItemLibrary.by_id(id) != null:
			key_items[id] = int(raw.get("count", 1))
	changed.emit()
