class_name Inventory
extends RefCounted
## The player's bag: a limited number of slots, each holding a stack of one
## item. Capacity = BASE_SLOTS + the best backpack owned. Lives on
## Game.inventory and is saved with the slot (to_dict/from_dict).
## Equipment is not stored here — see PlayerStats' owned_*/equipped_*.

signal changed

const BASE_SLOTS := 10

## Each entry: {"id": StringName, "count": int} (+ "sizes": Array of float, one
## per item, for ItemData.sized items like fish). Compact (no empty gaps) and
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

var _hold_cursor: Dictionary = {}   ## id -> which of a stack's sizes the next "hold up" shows (cycles through them)

## Adds up to `amount` of `id`; returns how many did NOT fit (0 = all stored).
## `size` is the size multiplier of the new item(s) if the item is `sized` (fish).
func add(id: StringName, amount := 1, size := 1.0) -> int:
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
			_push_sizes(s, item, put, size)
			left -= put
	while left > 0 and stacks.size() < capacity():
		var put := mini(left, item.max_stack)
		var stack := {"id": id, "count": put}
		_push_sizes(stack, item, put, size)
		stacks.append(stack)
		left -= put
	var stored := amount - left
	if stored > 0:
		Events.item_gained.emit(id, stored)
		changed.emit()
	if left > 0:
		Events.inventory_full.emit(id)
	return left

func _push_sizes(stack: Dictionary, item: ItemData, n: int, size: float) -> void:
	if not item.sized:
		return
	var sizes: Array = stack.get("sizes", [])
	for i in n:
		sizes.append(size)
	stack["sizes"] = sizes

## The individual sizes in stack `index` (empty for an item that has none).
func sizes_at(index: int) -> Array:
	if index < 0 or index >= stacks.size():
		return []
	var sizes: Array = stacks[index].get("sizes", [])
	while sizes.size() < stacks[index]["count"] and ItemLibrary.by_id(stacks[index]["id"]).sized:
		sizes.append(1.0)   # an older save that predates sizes
	stacks[index]["sizes"] = sizes
	return sizes

## Holds up one item of stack `index` at `size` (see HeldItem). Returns a short message.
func hold(index: int, size: float) -> String:
	if index < 0 or index >= stacks.size():
		return ""
	var item := ItemLibrary.by_id(stacks[index]["id"])
	if item == null or not item.holdable:
		return ""
	var problem := HeldItem.start(item, size)
	return problem if problem != "" else "Holding up the %s." % item.display_name

## The size of the next fish to hold up from stack `index`: cycles through the
## stack so each press shows a different one.
func next_hold_size(index: int) -> float:
	var sizes := sizes_at(index)
	if sizes.is_empty():
		return 1.0
	var id: StringName = stacks[index]["id"]
	var i := int(_hold_cursor.get(id, -1)) + 1
	if i >= sizes.size():
		i = 0
	_hold_cursor[id] = i
	return float(sizes[i])

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
	var sizes: Array = stacks[index].get("sizes", [])
	for i in mini(take, sizes.size()):
		sizes.pop_back()   # the newest ones go first
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
	if item == null:
		return ""
	if item.holdable:
		return hold(index, next_hold_size(index))
	if not item.is_usable():
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
		"stacks": stacks.map(func(s):
			var d := {"id": String(s["id"]), "count": s["count"]}
			if s.has("sizes"):
				d["sizes"] = s["sizes"].duplicate()
			return d),
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
			var stack := {"id": id, "count": int(raw.get("count", 1))}
			if item.sized:
				stack["sizes"] = Array(raw.get("sizes", []))
			stacks.append(stack)
	for raw in d.get("key_items", []):
		var id := LegacyIds.fix(StringName(raw.get("id", "")))
		if ItemLibrary.by_id(id) != null:
			key_items[id] = int(raw.get("count", 1))
	changed.emit()
