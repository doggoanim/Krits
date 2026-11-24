class_name ItemLibrary
extends RefCounted
## Code-defined item + backpack catalog, same spirit as EquipmentLibrary.
## Add a builder, add it to all_items() — it's saveable, droppable and (if it
## has a buy_price) sold by every shop. Names and descriptions are NOT here —
## they live in data/descriptions.cfg ([names] / [items]). Icons: drop a PNG at
## res://assets/items/<id>.png and it's picked up automatically.

## false = every slot shows the first letter of its name in its colour instead of an
## icon PNG. Set to true to start using PNGs dropped in ICON_DIR again.
const USE_ICON_FILES := false
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

## Marta's baking, cheap and filling.
static func bread_roll() -> ItemData:
	var i := _make(&"bread_roll", ItemData.Category.CONSUMABLE,
		Color(0.85, 0.65, 0.35), 6, 2)
	i.heal_hp = 15.0
	return i

static func jelly_bun() -> ItemData:
	var i := _make(&"jelly_bun", ItemData.Category.CONSUMABLE,
		Color(0.9, 0.35, 0.45), 14, 5)
	i.heal_hp = 30.0
	i.heal_shield = 10.0
	return i

static func shield_salve() -> ItemData:
	var i := _make(&"shield_salve", ItemData.Category.CONSUMABLE,
		Color(0.55, 0.8, 0.95), 18, 7)
	i.heal_shield = 40.0
	return i

static func greater_health_potion() -> ItemData:
	var i := _make(&"greater_health_potion", ItemData.Category.CONSUMABLE,
		Color(1.0, 0.25, 0.4), 80, 32)
	i.heal_hp = 100.0
	return i

static func spirit_elixir() -> ItemData:
	var i := _make(&"spirit_elixir", ItemData.Category.CONSUMABLE,
		Color(0.6, 1.0, 0.9), 200, 80)
	i.heal_hp = 150.0
	i.heal_shield = 9999.0
	return i

# ---------------------------------------------------------------- materials
static func slime_goo() -> ItemData:
	return _make(&"slime_goo", ItemData.Category.MATERIAL,
		Color(0.45, 0.75, 0.3), 0, 4)

# ---------------------------------------------------------------- loot (enemy drops and finds in the well)
static func rusty_cog() -> ItemData:   ## spinners
	return _make(&"rusty_cog", ItemData.Category.MATERIAL, Color(0.6, 0.45, 0.35), 0, 10)

static func piercer_spike() -> ItemData:   ## piercers
	return _make(&"piercer_spike", ItemData.Category.MATERIAL, Color(0.75, 0.75, 0.8), 0, 12)

static func cave_moss() -> ItemData:
	return _make(&"cave_moss", ItemData.Category.MATERIAL, Color(0.3, 0.55, 0.3), 0, 4)

static func glow_shard() -> ItemData:   ## chipped from the well's cyan crystals
	return _make(&"glow_shard", ItemData.Category.MATERIAL, Color(0.4, 0.95, 1.0), 0, 40)

static func old_coin() -> ItemData:
	return _make(&"old_coin", ItemData.Category.MATERIAL, Color(0.85, 0.7, 0.3), 0, 25)

static func spider_silk() -> ItemData:
	return _make(&"spider_silk", ItemData.Category.MATERIAL, Color(0.92, 0.93, 0.97), 0, 12)

# ---------------------------------------------------------------- fish (see FishCatalog)
static func minnow() -> ItemData:
	return _make(&"minnow", ItemData.Category.MATERIAL, Color(0.7, 0.8, 0.85), 0, 6)

static func perch() -> ItemData:
	return _make(&"perch", ItemData.Category.MATERIAL, Color(0.55, 0.75, 0.4), 0, 14)

static func silver_trout() -> ItemData:
	return _make(&"silver_trout", ItemData.Category.MATERIAL, Color(0.82, 0.88, 0.95), 0, 32)

static func golden_koi() -> ItemData:
	return _make(&"golden_koi", ItemData.Category.MATERIAL, Color(1.0, 0.8, 0.3), 0, 140)

static func bluegill() -> ItemData:
	return _make(&"bluegill", ItemData.Category.MATERIAL, Color(0.4, 0.6, 0.9), 0, 8)

static func carp() -> ItemData:
	return _make(&"carp", ItemData.Category.MATERIAL, Color(0.75, 0.6, 0.35), 0, 12)

static func catfish() -> ItemData:
	return _make(&"catfish", ItemData.Category.MATERIAL, Color(0.5, 0.45, 0.4), 0, 28)

static func pike() -> ItemData:
	return _make(&"pike", ItemData.Category.MATERIAL, Color(0.45, 0.65, 0.45), 0, 40)

static func rainbow_trout() -> ItemData:
	return _make(&"rainbow_trout", ItemData.Category.MATERIAL, Color(0.9, 0.55, 0.8), 0, 55)

static func lantern_eel() -> ItemData:
	return _make(&"lantern_eel", ItemData.Category.MATERIAL, Color(0.5, 0.95, 0.9), 0, 90)

static func moon_puffer() -> ItemData:
	return _make(&"moon_puffer", ItemData.Category.MATERIAL, Color(0.85, 0.85, 1.0), 0, 120)

static func old_sturgeon() -> ItemData:
	return _make(&"old_sturgeon", ItemData.Category.MATERIAL, Color(0.45, 0.55, 0.5), 0, 220)

static func blind_cavefish() -> ItemData:
	return _make(&"blind_cavefish", ItemData.Category.MATERIAL, Color(0.95, 0.88, 0.88), 0, 14)

static func glow_guppy() -> ItemData:
	return _make(&"glow_guppy", ItemData.Category.MATERIAL, Color(0.45, 0.95, 0.9), 0, 26)

static func spirit_koi() -> ItemData:
	return _make(&"spirit_koi", ItemData.Category.MATERIAL, Color(0.7, 0.88, 1.0), 0, 180)

# ---------------------------------------------------------------- key items
static func key() -> ItemData:
	var i := _make(&"key", ItemData.Category.KEY,
		Color(0.9, 0.8, 0.4))
	i.max_stack = 1
	return i

## The main quest's cargo: spirits gathered from the bottom of Chesburg's well.
static func water_spirits() -> ItemData:
	var i := _make(&"water_spirits", ItemData.Category.KEY,
		Color(0.5, 0.85, 1.0))
	i.max_stack = 1
	i.important = true   # collecting them plays the item-get fanfare (see ItemGet)
	i.model = preload("res://world/water_spirit.tscn")
	return i

## Yule's lost ball, from the side quest at the start of the well.
static func yule_ball() -> ItemData:
	var i := _make(&"yule_ball", ItemData.Category.KEY,
		Color(0.95, 0.3, 0.25))
	i.max_stack = 1
	return i

## Henry the hiker's pack, from the ledge side quest outside town.
static func hiker_pack() -> ItemData:
	var i := _make(&"hiker_pack", ItemData.Category.KEY,
		Color(0.7, 0.5, 0.3))
	i.max_stack = 1
	return i

## Hangs on the player's left hip and lights their way (see HipLantern).
static func lantern() -> ItemData:
	var i := _make(&"lantern", ItemData.Category.KEY,
		Color(0.95, 0.93, 0.79))
	i.max_stack = 1
	i.important = true
	i.model = preload("res://assets/equipments/lantern.glb")
	return i

static func all_items() -> Array[ItemData]:
	return [health_potion(), shield_restore(), bread_roll(), jelly_bun(), shield_salve(), greater_health_potion(), spirit_elixir(),
		slime_goo(), rusty_cog(), piercer_spike(), cave_moss(), glow_shard(), old_coin(), spider_silk(), key(), water_spirits(), lantern(), yule_ball(), hiker_pack(), minnow(), perch(), silver_trout(), golden_koi(),
		bluegill(), carp(), catfish(), pike(), rainbow_trout(), lantern_eel(), moon_puffer(), old_sturgeon(),
		blind_cavefish(), glow_guppy(), spirit_koi()]

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
	if FishCatalog.is_fish(id):
		i.sized = true
		i.holdable = true
	var path := ICON_DIR + String(id) + ".png"
	if USE_ICON_FILES and ResourceLoader.exists(path):
		i.icon = load(path)
	return i

static func _bag(id: StringName, price: int, slots: int) -> BackpackData:
	var b := BackpackData.new()
	b.id = id
	b.display_name = Descriptions.text("names", id)
	b.price = price
	b.slots = slots
	return b
