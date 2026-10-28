class_name InventorySlot
extends Button
## One square in the inventory grid: an item's icon (or a coloured initial
## when it has no art yet) and its stack count. Looks (nine-sliced plates)
## are applied by InventoryMenu; this only fills the contents.

@onready var _icon: TextureRect = %Icon
@onready var _initial: Label = %Initial
@onready var _count: Label = %Count

func show_item(item: ItemData, count: int) -> void:
	_icon.texture = item.icon
	_icon.visible = item.icon != null
	_initial.visible = item.icon == null
	_initial.text = item.display_name.left(1)
	_initial.add_theme_color_override(&"font_color", item.color)
	_count.text = "x%d" % count if count > 1 else ""

func show_empty() -> void:
	_icon.visible = false
	_initial.visible = false
	_count.text = ""
