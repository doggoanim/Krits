class_name InventorySlot
extends Button
## One square in the inventory grid: an item's icon (or a coloured initial
## when it has no art yet) and its stack count. Looks (nine-sliced plates)
## are applied by InventoryMenu; this only fills the contents.

@onready var _icon: TextureRect = %Icon
@onready var _initial: Label = %Initial
@onready var _count: Label = %Count
@onready var _key: Label = %Key               ## hotbar number, top-left (hidden unless set)
@onready var _cooldown: ColorRect = %Cooldown ## dark wipe that drains upward while an ability recharges

func show_item(item: ItemData, count: int) -> void:
	_icon.texture = item.icon
	_icon.visible = item.icon != null
	_initial.visible = item.icon == null
	_initial.text = item.display_name.left(1)
	_initial.add_theme_color_override(&"font_color", item.color)
	_count.text = "x%d" % count if count > 1 else ""

## Any other thing worth showing in a slot (shop gear, backpacks...).
func show_custom(icon: Texture2D, label: String, color: Color, count_text := "") -> void:
	_icon.texture = icon
	_icon.visible = icon != null
	_initial.visible = icon == null
	_initial.text = label
	_initial.add_theme_color_override(&"font_color", color)
	_count.text = count_text

## Applies nine-sliced plates (normal, hover, pressed) to a slot and lets
## FocusPop pick among them on focus. Shared by every screen with a slot grid.
static func apply_styles(slot: InventorySlot, styles: Array[StyleBox]) -> void:
	if styles.size() < 3:
		return
	slot.add_theme_stylebox_override(&"normal", styles[0])
	slot.add_theme_stylebox_override(&"hover", styles[1])
	slot.add_theme_stylebox_override(&"pressed", styles[2])
	slot.set_meta(FocusPop.LOOKS_META, styles)

func show_empty() -> void:
	_icon.visible = false
	_initial.visible = false
	_count.text = ""

func show_ability(ability: AbilityData) -> void:
	_icon.texture = ability.icon
	_icon.visible = ability.icon != null
	_initial.visible = ability.icon == null
	_initial.text = ability.display_name.left(1)
	_initial.add_theme_color_override(&"font_color", ability.color)
	_count.text = ""

## Hotbar number shown in the corner ("" hides it).
func set_key_text(text: String) -> void:
	_key.text = text

## 0 = ready ... 1 = just used.
func set_cooldown(fraction: float) -> void:
	_cooldown.visible = fraction > 0.0
	_cooldown.anchor_top = 1.0 - fraction

## Greys the slot out (e.g. a hotbar consumable you've run out of).
func set_dim(dim: bool) -> void:
	modulate.a = 0.45 if dim else 1.0
