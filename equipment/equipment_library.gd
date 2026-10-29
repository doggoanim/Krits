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

static func starting_armor() -> ArmorData: return tunic()
static func starting_shield() -> ShieldData: return wooden_shield()
static func starting_weapon() -> WeaponData: return wooden_sword()

# ---------------------------------------------------------------- armor
static func tunic() -> ArmorData:
	var a := ArmorData.new()
	a.id = &"tunic"
	a.price = 0
	a.hp_bonus = 0.0
	a.display_name = Descriptions.text("names", a.id)
	return a

static func leather_armor() -> ArmorData:
	var a := ArmorData.new()
	a.id = &"leather_armor"
	a.price = 50
	a.hp_bonus = 40.0
	a.display_name = Descriptions.text("names", a.id)
	return a

static func iron_plate() -> ArmorData:
	var a := ArmorData.new()
	a.id = &"iron_plate"
	a.price = 150
	a.hp_bonus = 90.0
	a.display_name = Descriptions.text("names", a.id)
	return a

static func all_armors() -> Array[ArmorData]:
	return [tunic(), leather_armor(), iron_plate()]

# ---------------------------------------------------------------- shield
static func wooden_shield() -> ShieldData:
	var s := ShieldData.new()
	s.id = &"wooden_shield"
	s.price = 0
	s.shield_bonus = 10.0
	_look(s, "shield_wooden", 0.26, Vector3.ZERO, Vector3.ZERO)
	s.display_name = Descriptions.text("names", s.id)
	return s

static func round_shield() -> ShieldData:
	var s := ShieldData.new()
	s.id = &"round_shield"
	s.price = 50
	s.shield_bonus = 30.0
	s.display_name = Descriptions.text("names", s.id)
	return s

static func tower_shield() -> ShieldData:
	var s := ShieldData.new()
	s.id = &"tower_shield"
	s.price = 150
	s.shield_bonus = 70.0
	s.display_name = Descriptions.text("names", s.id)
	return s

static func all_shields() -> Array[ShieldData]:
	return [wooden_shield(), round_shield(), tower_shield()]

# ---------------------------------------------------------------- weapon
static func wooden_sword() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"wooden_sword"
	w.price = 0
	w.kind = WeaponData.Kind.SWORD
	w.damage_bonus = 0.5
	# Hangs from the shield's top edge by its handle, blade pointing down. The
	# glb's origin is the pommel with the blade along +Y, so flip it 180° and
	# shift it up so the handle (not the pommel) sits on the hang point.
	_look(w, "sword_wooden", 0.3, Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.0, 180.0))
	w.display_name = Descriptions.text("names", w.id)
	return w

static func steel_sword() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"steel_sword"
	w.price = 60
	w.kind = WeaponData.Kind.SWORD
	w.damage_bonus = 5.0
	w.display_name = Descriptions.text("names", w.id)
	return w

static func wooden_bow() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"wooden_bow"
	w.price = 80
	w.kind = WeaponData.Kind.BOW
	w.damage_bonus = 0.5
	# The glb is ~2 units tall, centred on its grip, limbs along +/-Y. Hung by
	# its top tip from the shield's top edge: shift down by half its scaled height.
	_look(w, "bow_wooden", 0.3, Vector3(0.0, -0.3, 0.0), Vector3.ZERO)
	w.display_name = Descriptions.text("names", w.id)
	return w

static func apprentice_staff() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"apprentice_staff"
	w.price = 80
	w.kind = WeaponData.Kind.STAFF
	w.damage_bonus = 0.5
	# The glb's origin is the butt of the staff, the head ~2.2 units up +Y.
	# Flipped 180° so it hangs by its butt end with the head dangling, like the sword.
	_look(w, "staff_apprentice", 0.28, Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.0, 180.0))
	w.display_name = Descriptions.text("names", w.id)
	return w

static func all_weapons() -> Array[WeaponData]:
	return [wooden_sword(), steel_sword(), wooden_bow(), apprentice_staff()]

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

# ---------------------------------------------------------------- worn look
## Attaches assets/equipments/<file>.glb (if it exists) as the item's worn
## model. A missing file just means "nothing shown" — never an error.
static func _look(item: EquipmentData, file: String, model_scale: float,
		offset: Vector3, rotation_deg: Vector3) -> void:
	var path := "res://assets/equipments/%s.glb" % file
	if not ResourceLoader.exists(path):
		return
	item.model = load(path)
	item.model_scale = model_scale
	item.model_offset = offset
	item.model_rotation_deg = rotation_deg

## One-line stat summary ("Armor: +20 max HP") for item details everywhere.
static func stat_line(item: EquipmentData) -> String:
	if item is ArmorData: return "Armor: +%d max HP" % item.hp_bonus
	if item is ShieldData: return "Shield: +%d max shield" % item.shield_bonus
	if item is WeaponData: return "Weapon: %s damage" % String.num(item.damage_bonus)
	return ""
