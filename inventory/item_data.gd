class_name ItemData
extends Resource
## One kind of carriable item (potion, monster drop, key...). Equipment is NOT
## an ItemData — armor/shields/weapons live in EquipmentData and don't take
## bag slots. Built by ItemLibrary; `id` is what gets saved.

enum Category { CONSUMABLE, MATERIAL, KEY }

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.MATERIAL
@export var max_stack := 99               ## how many fit in one slot (key items: 1)
@export var buy_price := 0                ## 0 = shops don't sell it
@export var sell_price := 0               ## 0 = can't be sold
@export var icon: Texture2D               ## optional; slots fall back to a coloured initial
@export var color := Color(0.8, 0.8, 0.8) ## tint for the fallback icon

@export_group("Consumable effect")
@export var heal_hp := 0.0
@export var heal_shield := 0.0

func is_usable() -> bool:
	return category == Category.CONSUMABLE

func can_drop() -> bool:
	return category != Category.KEY

func category_name() -> String:
	match category:
		Category.CONSUMABLE: return "Consumable"
		Category.KEY: return "Key item"
		_: return "Material"
