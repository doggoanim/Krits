class_name EquipmentData
extends Resource
## Shared fields every piece of gear has, regardless of slot — see
## ArmorData/ShieldData/WeaponData for the slot-specific stat each adds.
## Built the same way EnemyData is: either a static builder in
## EquipmentLibrary (plain code, easy to tweak) or a saved .tres if content
## grows past that. `id` is what actually gets saved/loaded and looked back
## up through EquipmentLibrary.by_id() — see PlayerStats.to_dict()/from_dict()
## — not the Resource object itself, which a JSON save can't hold.

@export var id: StringName = &""
@export var display_name := ""
@export var price := 0

## Flavor text, read from data/descriptions.cfg ([gear] section).
func flavor() -> String:
	return Descriptions.text("gear", id)
