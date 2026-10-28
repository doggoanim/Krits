class_name PlayerStats
extends RefCounted
## HP, Shield, Damage, and gold. Stats are entirely equipment-driven now —
## see equipment/ — rather than levels/spent points: max_hp()/max_shield()/
## damage() just read off whatever's currently equipped. Shield is a second
## bar that recharges after a delay. Piercing hits skip it.
##
## owned_* holds the ids (not the Resource objects — a JSON save can't hold
## those) of every item of that slot the player has ever bought, so
## re-equipping something already owned is free; the starting item's id is
## always in there so there's always something free to fall back to.
## equipped_* holds the actual resolved EquipmentData for whatever's
## currently worn/wielded — that's what max_hp()/max_shield()/damage() read.

const BASE_HP := 100.0
const BASE_SHIELD := 0.0    ## no shield worn = no shield bar
const BASE_DAMAGE := 1.0   ## orb hits are the only thing that uses this — combo scaling
                           ## (see Arena.COMBO_BONUS) still ramps up from here as normal
const SHIELD_RECHARGE_DELAY := 3.0
const SHIELD_RECHARGE_RATE := 12.0

var gold := 0
var owned_armors: Array[StringName] = []
var owned_shields: Array[StringName] = []
var owned_weapons: Array[StringName] = []
var equipped_armor: ArmorData
var equipped_shield: ShieldData
var equipped_weapon: WeaponData

var hp := BASE_HP
var shield := BASE_SHIELD
var _since_hit := 0.0

func _init() -> void:
	equipped_armor = EquipmentLibrary.starting_armor()
	equipped_shield = EquipmentLibrary.starting_shield()
	equipped_weapon = EquipmentLibrary.starting_weapon()
	owned_armors = [equipped_armor.id]
	owned_shields = [equipped_shield.id]
	owned_weapons = [equipped_weapon.id]
	hp = max_hp()
	shield = max_shield()

func max_hp() -> float: return BASE_HP + (equipped_armor.hp_bonus if equipped_armor else 0.0)
func max_shield() -> float: return BASE_SHIELD + (equipped_shield.shield_bonus if equipped_shield else 0.0)
func damage() -> float: return BASE_DAMAGE + (equipped_weapon.damage_bonus if equipped_weapon else 0.0)

func tick(delta: float) -> void:
	_since_hit += delta
	if _since_hit >= SHIELD_RECHARGE_DELAY and shield < max_shield():
		shield = minf(max_shield(), shield + SHIELD_RECHARGE_RATE * delta)

## Returns true if the player died.
func take_damage(amount: float, pierces_shield := false) -> bool:
	_since_hit = 0.0
	if pierces_shield:
		hp -= amount
	else:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		hp -= amount - absorbed
	hp = maxf(hp, 0.0)
	Events.player_damaged.emit(hp, shield)
	return hp <= 0.0

func full_heal() -> void:
	hp = max_hp()
	shield = max_shield()
	Events.player_damaged.emit(hp, shield)

## Restores hp and shield (clamped to their maximums).
func heal(hp_amount: float, shield_amount := 0.0) -> void:
	hp = minf(max_hp(), hp + hp_amount)
	shield = minf(max_shield(), shield + shield_amount)
	Events.player_damaged.emit(hp, shield)
	Events.stats_changed.emit()

func add_gold(amount: int) -> void:
	gold += amount
	Events.stats_changed.emit()

## ShopMenu's one entry point: buys `item` if it's affordable and not
## already owned (free to re-buy — i.e. re-equip — if it is), then equips
## it either way. False only means "couldn't afford it and don't own it
## yet" — nothing is changed in that case.
func buy(item: EquipmentData) -> bool:
	if not _owns(item) and item.price > gold:
		return false
	if not _owns(item):
		gold -= item.price
		_owned_list(item).append(item.id)
	equip(item)
	return true

func is_owned(item: EquipmentData) -> bool:
	return _owns(item)

## Takes the armor or shield off (back to the base stat). Weapons can't be
## removed. `slot_item` is any item of the slot to clear, e.g. the equipped one.
func unequip(slot_item: EquipmentData) -> void:
	if slot_item is ArmorData:
		equipped_armor = null
		hp = minf(hp, max_hp())
	elif slot_item is ShieldData:
		equipped_shield = null
		shield = minf(shield, max_shield())
	else:
		return
	Events.stats_changed.emit()

func equip(item: EquipmentData) -> void:
	if item is ArmorData:
		equipped_armor = item
		hp = minf(hp, max_hp())
	elif item is ShieldData:
		equipped_shield = item
		shield = minf(shield, max_shield())
	elif item is WeaponData:
		equipped_weapon = item
	Events.stats_changed.emit()

func _owns(item: EquipmentData) -> bool:
	return item.id in _owned_list(item)

func _owned_list(item: EquipmentData) -> Array:
	if item is ArmorData: return owned_armors
	if item is ShieldData: return owned_shields
	return owned_weapons

func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"owned_armors": owned_armors.map(func(id): return String(id)),
		"owned_shields": owned_shields.map(func(id): return String(id)),
		"owned_weapons": owned_weapons.map(func(id): return String(id)),
		"equipped_armor": String(equipped_armor.id) if equipped_armor else "",
		"equipped_shield": String(equipped_shield.id) if equipped_shield else "",
		"equipped_weapon": String(equipped_weapon.id) if equipped_weapon else "",
	}

func from_dict(d: Dictionary) -> void:
	gold = int(d.get("gold", 0))
	owned_armors = _load_id_array(d.get("owned_armors", []), EquipmentLibrary.starting_armor().id)
	owned_shields = _load_id_array(d.get("owned_shields", []), EquipmentLibrary.starting_shield().id)
	owned_weapons = _load_id_array(d.get("owned_weapons", []), EquipmentLibrary.starting_weapon().id)
	# A missing key means an old save (wear the starter); an empty string means
	# "deliberately took it off".
	equipped_armor = EquipmentLibrary.by_id(StringName(d.get("equipped_armor", ""))) as ArmorData
	if equipped_armor == null and d.has("equipped_armor") == false:
		equipped_armor = EquipmentLibrary.starting_armor()
	equipped_shield = EquipmentLibrary.by_id(StringName(d.get("equipped_shield", ""))) as ShieldData
	if equipped_shield == null and d.has("equipped_shield") == false:
		equipped_shield = EquipmentLibrary.starting_shield()
	equipped_weapon = EquipmentLibrary.by_id(StringName(d.get("equipped_weapon", ""))) as WeaponData
	if equipped_weapon == null: equipped_weapon = EquipmentLibrary.starting_weapon()
	full_heal()

## Shared by the three owned_* loaders: StringName-ifies every saved id,
## always making sure `fallback` (the slot's starting item) is in there even
## on an old save from before it existed, so there's always something to
## equip even if a saved id no longer resolves through EquipmentLibrary.
func _load_id_array(raw: Array, fallback: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in raw:
		out.append(StringName(id))
	if fallback not in out:
		out.append(fallback)
	return out
