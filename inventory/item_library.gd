class_name ItemLibrary
extends RefCounted
## Code-defined item + backpack catalog, same spirit as EquipmentLibrary.
## Add a builder, add it to all_items() — it's saveable, droppable and (if it
## has a buy_price) sold by every shop. Names and descriptions are NOT here —
## they live in data/descriptions.cfg ([names] / [items]). Icons: drop a PNG at
## res://assets/items/<id>.png and it's picked up automatically.

const ICON_DIR := "res://assets/items/"

# ---------------------------------------------------------------- consumables
static func health_potion() -> ItemData:
	var i := _make(&"health_potion", ItemData.Category.CONSUMABLE,
		Color(1.0, 0.4, 0.45), 30, 12)
	i.heal_hp = 40.0
	return i

static func shield_restore() -> ItemData:
	var i := _make(&"shield_restore", ItemData.Category.CONSUMABLE,
		Color(0.4, 0.7, 1.0), 25, 10)
	i.heal_shield = 9999.0
	return i

# ---------------------------------------------------------------- materials
static func slime_goo() -> ItemData:
	return _make(&"slime_goo", ItemData.Category.MATERIAL,
		Color(0.45, 0.75, 0.3), 0, 4)

# ---------------------------------------------------------------- key items
static func key() -> ItemData:
	var i := _make(&"key", ItemData.Category.KEY,
		Color(0.9, 0.8, 0.4))
	i.max_stack = 1
	return i

static func all_items() -> Array[ItemData]:
	return [health_potion(), shield_restore(), slime_goo(), key()]

static func by_id(id: StringName) -> ItemData:
	for item in all_items():
		if item.id == id:
			return item
	return null

# ---------------------------------------------------------------- backpacks
static func small_backpack() -> BackpackData:
	return _bag(&"small_backpack", 60, 6)

static func medium_backpack() -> BackpackData:
	return _bag(&"medium_backpack", 180, 12)

static func large_backpack() -> BackpackData:
	return _bag(&"large_backpack", 420, 20)

static func all_backpacks() -> Array[BackpackData]:
	return [small_backpack(), medium_backpack(), large_backpack()]

static func backpack_by_id(id: StringName) -> BackpackData:
	for b in all_backpacks():
		if b.id == id:
			return b
	return null

# ---------------------------------------------------------------- helpers
static func _make(id: StringName, cat: ItemData.Category,
		color: Color, buy := 0, sell := 0) -> ItemData:
	var i := ItemData.new()
	i.id = id
	i.display_name = Descriptions.text("names", id)
	i.category = cat
	i.description = Descriptions.text("items", id)
	i.color = color
	i.buy_price = buy
	i.sell_price = sell
	var path := ICON_DIR + String(id) + ".png"
	if ResourceLoader.exists(path):
		i.icon = load(path)
	return i

static func _bag(id: StringName, price: int, slots: int) -> BackpackData:
	var b := BackpackData.new()
	b.id = id
	b.display_name = Descriptions.text("names", id)
	b.price = price
	b.slots = slots
	return b
