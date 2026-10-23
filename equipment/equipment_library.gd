class_name EquipmentLibrary
extends RefCounted
## Code-defined equipment catalog, same spirit as EnemyLibrary — one static
## builder per item, move to .tres resources if content grows past this.
##
## Every item has a stable `id` (see EquipmentData) — that's what actually
## gets saved in PlayerStats' owned/equipped lists, resolved back to the
## real Resource through by_id() on load. The *_armors()/*_shields()/
## *_weapons() lists are what ShopMenu displays and what new content gets
## added to; starting_*() are what a fresh PlayerStats equips by default so
## HP/shield/damage aren't zero before the player's ever bought anything —
## their bonuses are deliberately 0 so a fresh save's numbers match the
## old flat BASE_HP/BASE_SHIELD/BASE_DAMAGE exactly.

static func starting_armor() -> ArmorData: return cloth_tunic()
static func starting_shield() -> ShieldData: return buckler()
static func starting_weapon() -> WeaponData: return rusty_sword()

# ---------------------------------------------------------------- armor
static func cloth_tunic() -> ArmorData:
	var a := ArmorData.new()
	a.id = &"cloth_tunic"
	a.display_name = "Cloth Tunic"
	a.price = 0
	a.hp_bonus = 0.0
	return a

static func leather_armor() -> ArmorData:
	var a := ArmorData.new()
	a.id = &"leather_armor"
	a.display_name = "Leather Armor"
	a.price = 50
	a.hp_bonus = 40.0
	return a

static func iron_plate() -> ArmorData:
	var a := ArmorData.new()
	a.id = &"iron_plate"
	a.display_name = "Iron Plate"
	a.price = 150
	a.hp_bonus = 90.0
	return a

static func all_armors() -> Array[ArmorData]:
	return [cloth_tunic(), leather_armor(), iron_plate()]

# ---------------------------------------------------------------- shield
static func buckler() -> ShieldData:
	var s := ShieldData.new()
	s.id = &"buckler"
	s.display_name = "Buckler"
	s.price = 0
	s.shield_bonus = 0.0
	return s

static func round_shield() -> ShieldData:
	var s := ShieldData.new()
	s.id = &"round_shield"
	s.display_name = "Round Shield"
	s.price = 50
	s.shield_bonus = 30.0
	return s

static func tower_shield() -> ShieldData:
	var s := ShieldData.new()
	s.id = &"tower_shield"
	s.display_name = "Tower Shield"
	s.price = 150
	s.shield_bonus = 70.0
	return s

static func all_shields() -> Array[ShieldData]:
	return [buckler(), round_shield(), tower_shield()]

# ---------------------------------------------------------------- weapon
static func rusty_sword() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"rusty_sword"
	w.display_name = "Rusty Sword"
	w.price = 0
	w.kind = WeaponData.Kind.SWORD
	w.damage_bonus = 0.0
	return w

static func steel_sword() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"steel_sword"
	w.display_name = "Steel Sword"
	w.price = 60
	w.kind = WeaponData.Kind.SWORD
	w.damage_bonus = 4.0
	return w

static func hunter_bow() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"hunter_bow"
	w.display_name = "Hunter's Bow"
	w.price = 80
	w.kind = WeaponData.Kind.BOW
	w.damage_bonus = 3.0
	return w

static func apprentice_staff() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"apprentice_staff"
	w.display_name = "Apprentice Staff"
	w.price = 80
	w.kind = WeaponData.Kind.STAFF
	w.damage_bonus = 3.0
	return w

static func all_weapons() -> Array[WeaponData]:
	return [rusty_sword(), steel_sword(), hunter_bow(), apprentice_staff()]

# ---------------------------------------------------------------- lookup
## Resolves a saved id back to its real EquipmentData, regardless of slot —
## null if it's not in the catalog (a save from a build where that item's
## since been removed/renamed). Callers (PlayerStats.from_dict()) fall back
## to the matching starting_*() item when this returns null, same as a
## fresh save, rather than leaving a slot pointed at nothing.
static func by_id(item_id: StringName) -> EquipmentData:
	if item_id == &"":
		return null
	for a in all_armors():
		if a.id == item_id: return a
	for s in all_shields():
		if s.id == item_id: return s
	for w in all_weapons():
		if w.id == item_id: return w
	return null
