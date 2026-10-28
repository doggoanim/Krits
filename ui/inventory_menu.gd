class_name InventoryMenu
extends MenuBase
## The bag screen (hotkey: "menu_inventory", default I). Two tabs:
##   Items — a grid of slots (Game.inventory; capacity grows with backpacks).
##           Pick a slot to read about it; Use / Drop buttons on the right.
##   Gear  — every armor/shield/weapon you own; pick one to equip it.
## Layout and art live in inventory_menu.tscn; this script fills in the
## dynamic parts (one slot per bag slot, one button per owned item).

@export var slot_scene: PackedScene
@export var slot_styles: Array[StyleBox] = []   ## nine-sliced plates: normal, hover, pressed

@onready var _gold: Label = %GoldLabel
@onready var _items_tab: Button = %ItemsTab
@onready var _gear_tab: Button = %GearTab
@onready var _items_page: Control = %ItemsPage
@onready var _gear_page: Control = %GearPage
@onready var _capacity: Label = %CapacityLabel
@onready var _grid: GridContainer = %Grid
@onready var _armor_list: VBoxContainer = %ArmorList
@onready var _shield_list: VBoxContainer = %ShieldList
@onready var _weapon_list: VBoxContainer = %WeaponList
@onready var _detail_name: Label = %DetailName
@onready var _detail_kind: Label = %DetailKind
@onready var _detail_text: Label = %DetailText
@onready var _message: Label = %Message
@onready var _use_button: Button = %UseButton
@onready var _drop_button: Button = %DropButton

const GEAR_ID_META := &"gear_id"

var _selected := 0                  ## index of the focused bag slot
var _gear_focus: StringName = &""   ## id of the focused gear button (restored after a rebuild)

func _init() -> void:
	toggle_action = &"menu_inventory"

func _ready() -> void:
	super()
	_items_tab.pressed.connect(_show_page.bind(true))
	_gear_tab.pressed.connect(_show_page.bind(false))
	_use_button.pressed.connect(_use_selected)
	_drop_button.pressed.connect(_drop_selected)

## The base class frees everything under Content on open; here Content holds
## the fixed layout from the scene, so leave it alone.
func _clear() -> void:
	pass

func open() -> void:
	super()
	if open_menu != self:
		return
	_message.text = ""
	_show_page(true)

func refresh() -> void:
	_gold.text = "Gold: %d" % Game.stats.gold
	_build_items()
	_build_gear()

# ---------------------------------------------------------------- pages

func _show_page(items: bool) -> void:
	_items_tab.set_pressed_no_signal(items)
	_gear_tab.set_pressed_no_signal(not items)
	_items_page.visible = items
	_gear_page.visible = not items
	_message.text = ""
	if items:
		_focus_selected_slot()
	else:
		_focus_gear.call_deferred()

# ---------------------------------------------------------------- items

func _build_items() -> void:
	var inv := Game.inventory
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var bag := inv.backpack()
	_capacity.text = "Bag %d / %d   (%s)" % [inv.stacks.size(), inv.capacity(),
		bag.display_name if bag else "no backpack"]
	_selected = clampi(_selected, 0, maxi(inv.capacity() - 1, 0))
	for i in inv.capacity():
		var slot := slot_scene.instantiate() as InventorySlot
		_grid.add_child(slot)
		_style_slot(slot)
		if i < inv.stacks.size():
			slot.show_item(ItemLibrary.by_id(inv.stacks[i]["id"]), inv.stacks[i]["count"])
		else:
			slot.show_empty()
		slot.focus_entered.connect(_on_slot_focused.bind(i))
		slot.pressed.connect(_on_slot_pressed.bind(i))
	FocusPop.attach_all(_grid)
	if _items_page.visible and visible:
		_focus_selected_slot()
	_update_item_details()

func _style_slot(slot: Button) -> void:
	if slot_styles.size() >= 3:
		slot.add_theme_stylebox_override(&"normal", slot_styles[0])
		slot.add_theme_stylebox_override(&"hover", slot_styles[1])
		slot.add_theme_stylebox_override(&"pressed", slot_styles[2])
		slot.set_meta(FocusPop.LOOKS_META, slot_styles)

func _focus_selected_slot() -> void:
	if _grid.get_child_count() == 0:
		return
	var slot := _grid.get_child(clampi(_selected, 0, _grid.get_child_count() - 1)) as Control
	slot.grab_focus.call_deferred()

func _on_slot_focused(index: int) -> void:
	_selected = index
	_message.text = ""
	_update_item_details()

func _on_slot_pressed(index: int) -> void:
	_selected = index
	_use_selected()

func _update_item_details() -> void:
	var stacks := Game.inventory.stacks
	var has_item := _selected < stacks.size()
	_use_button.visible = false
	_drop_button.visible = false
	if not has_item:
		_detail_name.text = "Empty slot"
		_detail_kind.text = ""
		_detail_text.text = ""
		return
	var item := ItemLibrary.by_id(stacks[_selected]["id"])
	_detail_name.text = item.display_name
	_detail_kind.text = "%s   x%d" % [item.category_name(), stacks[_selected]["count"]]
	var text := item.description
	if item.sell_price > 0:
		text += "\n\nSells for %dg." % item.sell_price
	_detail_text.text = text
	_use_button.visible = item.is_usable()
	_drop_button.visible = item.can_drop()
	_drop_button.text = "Drop 1"

func _use_selected() -> void:
	if _selected >= Game.inventory.stacks.size():
		return
	_message.text = Game.inventory.use(_selected)
	var keep := _message.text
	refresh()
	_message.text = keep

func _drop_selected() -> void:
	if _selected >= Game.inventory.stacks.size():
		return
	var item := ItemLibrary.by_id(Game.inventory.stacks[_selected]["id"])
	if item == null or not item.can_drop():
		return
	Game.inventory.remove_at(_selected, 1)
	_message.text = "Dropped %s." % item.display_name
	var keep := _message.text
	refresh()
	_message.text = keep

# ---------------------------------------------------------------- gear

func _build_gear() -> void:
	var s := Game.stats
	_fill_gear(_armor_list, s.owned_armors, s.equipped_armor)
	_fill_gear(_shield_list, s.owned_shields, s.equipped_shield)
	_fill_gear(_weapon_list, s.owned_weapons, s.equipped_weapon)
	FocusPop.attach_all(_gear_page)
	if _gear_page.visible and visible:
		_focus_gear.call_deferred()

func _fill_gear(list: VBoxContainer, owned: Array, equipped: EquipmentData) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for id in owned:
		var item := EquipmentLibrary.by_id(id)
		if item == null:
			continue
		var b := Button.new()
		var is_equipped := equipped != null and equipped.id == item.id
		b.text = ("★ " if is_equipped else "") + item.display_name
		b.add_theme_font_size_override(&"font_size", 40)
		b.set_meta(GEAR_ID_META, item.id)
		b.focus_entered.connect(_on_gear_focused.bind(item))
		b.pressed.connect(_equip.bind(item))
		list.add_child(b)

func _focus_gear() -> void:
	var fallback: Control
	for list in [_armor_list, _shield_list, _weapon_list]:
		for b in list.get_children():
			fallback = fallback if fallback else b
			if b.get_meta(GEAR_ID_META) == _gear_focus:
				b.grab_focus()
				return
	if fallback:
		fallback.grab_focus()

func _on_gear_focused(item: EquipmentData) -> void:
	_gear_focus = item.id
	_use_button.visible = false
	_drop_button.visible = false
	_detail_name.text = item.display_name
	var equipped := Game.stats.equipped_armor if item is ArmorData \
		else (Game.stats.equipped_shield if item is ShieldData else Game.stats.equipped_weapon)
	_detail_kind.text = "Equipped" if equipped != null and equipped.id == item.id else "Press to equip"
	_detail_text.text = _gear_text(item)

func _gear_text(item: EquipmentData) -> String:
	if item is ArmorData: return "Armor\n+%d max HP" % item.hp_bonus
	if item is ShieldData: return "Shield\n+%d max shield" % item.shield_bonus
	if item is WeaponData: return "Weapon\n+%d damage" % item.damage_bonus
	return ""

func _equip(item: EquipmentData) -> void:
	Game.stats.equip(item)   # emits stats_changed -> refresh()
	_message.text = "Equipped %s." % item.display_name
