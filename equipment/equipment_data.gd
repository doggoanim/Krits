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

## 3D look while worn (optional). Shields float behind the player and the
## weapon hangs off the back of the shield — see player/gear_display.gd.
## Offset/rotation are relative to that anchor, so they can be tuned per
## item; `model_scale` is applied on top of whatever size the glb was
## exported at.
@export var model: PackedScene
@export var model_scale := 1.0
@export var model_offset := Vector3.ZERO
@export var model_rotation_deg := Vector3.ZERO

## Flavor text, read from data/descriptions.cfg ([gear] section).
func flavor() -> String:
	return Descriptions.text("gear", id)
