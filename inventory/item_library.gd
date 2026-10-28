class_name ItemLibrary
extends RefCounted
## Code-defined item + backpack catalog, same spirit as EquipmentLibrary.
## Add a builder, add it to all_items() — it's saveable, droppable and (if it
## has a buy_price) sold by every shop. Icons: drop a PNG at
## res://assets/items/<id>.png and it's picked up automatically.

const ICON_DIR := "res://assets/items/"

# ---------------------------------------------------------------- consumables
static func health_potion() -> ItemData:
	var i := _make(&"health_potion", "Health Potion", ItemData.Category.CONSUMABLE,
		"A sweet red tonic. Restores 40 HP.", Color(1.0, 0.4, 0.45), 30, 12)
	i.heal_hp = 40.0
	return i

static func shield_tonic() -> ItemData:
	var i := _make(&"shield_tonic", "Shield Tonic", ItemData.Category.CONSUMABLE,
		"Fizzy blue stuff. Fully restores your shield.", Color(0.4, 0.7, 1.0), 25, 10)
	i.heal_shield = 9999.0
	return i

# ---------------------------------------------------------------- materials
static func slime_goo() -> ItemData:
	return _make(&"slime_goo", "Slime Goo", ItemData.Category.MATERIAL,
		"Wobbly and a little warm. Shops pay for it.", Color(0.45, 0.75, 0.3), 0, 4)

# ---------------------------------------------------------------- key items
static func old_key() -> ItemData:
	var i := _make(&"old_key", "Old Key", ItemData.Category.KEY,
		"Heavy and rusty. It must open something.", Color(0.9, 0.8, 0.4))
	i.max_stack = 1
	return i

static func all_items() -> Array[ItemData]:
	return [health_potion(), shield_tonic(), slime_goo(), old_key()]

static func by_id(id: StringName) -> ItemData:
	for item in all_items():
		if item.id == id:
			return item
	return null

# ---------------------------------------------------------------- backpacks
static func small_backpack() -> BackpackData:
	return _bag(&"small_backpack", "Small Backpack", 60, 6)

static func medium_backpack() -> BackpackData:
	return _bag(&"medium_backpack", "Medium Backpack", 180, 12)

static func large_backpack() -> BackpackData:
	return _bag(&"large_backpack", "Large Backpack", 420, 20)

static func all_backpacks() -> Array[BackpackData]:
	return [small_backpack(), medium_backpack(), large_backpack()]

static func backpack_by_id(id: StringName) -> BackpackData:
	for b in all_backpacks():
		if b.id == id:
			return b
	return null

# ---------------------------------------------------------------- helpers
static func _make(id: StringName, name: String, cat: ItemData.Category, desc: String,
		color: Color, buy := 0, sell := 0) -> ItemData:
	var i := ItemData.new()
	i.id = id
	i.display_name = name
	i.category = cat
	i.description = desc
	i.color = color
	i.buy_price = buy
	i.sell_price = sell
	var path := ICON_DIR + String(id) + ".png"
	if ResourceLoader.exists(path):
		i.icon = load(path)
	return i

static func _bag(id: StringName, name: String, price: int, slots: int) -> BackpackData:
	var b := BackpackData.new()
	b.id = id
	b.display_name = name
	b.price = price
	b.slots = slots
	return b
