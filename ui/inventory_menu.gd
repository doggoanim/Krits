class_name InventoryMenu
extends MenuBase
## The bag screen (hotkey: "menu_inventory", default Tab). Three tabs:
##   Items     — a grid of slots (Game.inventory; capacity grows with
##               backpacks). Pick one to read about it; Use / Drop, and put
##               consumables on hotbar slots 4-6.
##   Gear      — every armor/shield/weapon you own; pick one to equip it.
##   Abilities — the abilities you know; put them on hotbar slots 1-3.
## The hotbar itself is shown along the bottom (display only here — the
## number keys use it in the game, see HotbarBar). Layout and art live in
## inventory_menu.tscn; this script fills in the dynamic parts.

enum Page { ITEMS, GEAR, ABILITIES }

@export var slot_scene: PackedScene
@export var slot_styles: Array[StyleBox] = []   ## nine-sliced plates: normal, hover, pressed

@onready var _gold: Label = %GoldLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _tabs: Array[Button] = [%ItemsTab, %GearTab, %AbilitiesTab]
@onready var _pages: Array[Control] = [%ItemsPage, %GearPage, %AbilitiesPage]
@onready var _capacity: Label = %CapacityLabel
@onready var _grid: GridContainer = %Grid
@onready var _ability_grid: GridContainer = %AbilityGrid
@onready var _armor_list: VBoxContainer = %ArmorList
@onready var _shield_list: VBoxContainer = %ShieldList
@onready var _weapon_list: VBoxContainer = %WeaponList
@onready var _detail_name: Label = %DetailName
@onready var _detail_kind: Label = %DetailKind
@onready var _detail_text: Label = %DetailText
@onready var _message: Label = %Message
@onready var _use_button: Button = %UseButton
@onready var _drop_button: Button = %DropButton
@onready var _assign_label: Label = %AssignLabel
@onready var _assign_row: HBoxContainer = %AssignRow

const GEAR_ID_META := &"gear_id"

var _page := Page.ITEMS
var _selected := 0                  ## index of the focused bag slot
var _selected_ability := 0          ## index of the focused ability
var _gear_focus: StringName = &""   ## id of the focused gear button (restored after a rebuild)

func _init() -> void:
	toggle_action = &"menu_inventory"

func _ready() -> void:
	super()
	for i in _tabs.size():
		_tabs[i].pressed.connect(_show_page.bind(i))
	_use_button.pressed.connect(_use_selected)
	_drop_button.pressed.connect(_drop_selected)

## The base class frees everything under Content on open; here Content holds
## the fixed layout from the scene, so leave it alone.
func _clear() -> void:
	pass

## Tab is both the open key and a UI focus key, and a focused control would
## swallow it before MenuBase's _unhandled_input ever saw it — so while open,
## catch the toggle here, ahead of GUI focus handling.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(toggle_action):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	super()
	if open_menu != self:
		return
	_message.text = ""
	_show_page(Page.ITEMS)

func refresh() -> void:
	var s := Game.stats
	_gold.text = "Gold: %d" % s.gold
	_stats_label.text = "HP %d/%d   Shield %d/%d   Damage %d" % [s.hp, s.max_hp(), s.shield, s.max_shield(), s.damage()]
	_build_items()
	_build_gear()
	_build_abilities()

# ---------------------------------------------------------------- pages

func _show_page(page: int) -> void:
	_page = page as Page
	for i in _pages.size():
		_pages[i].visible = i == page
		_tabs[i].set_pressed_no_signal(i == page)
	_message.text = ""
	match _page:
		Page.ITEMS:
			_focus_selected_slot(_grid, _selected)
			_update_item_details()
		Page.GEAR:
			_focus_gear.call_deferred()
		Page.ABILITIES:
			_focus_selected_slot(_ability_grid, _selected_ability)
			_update_ability_details()

# ---------------------------------------------------------------- items

func _build_items() -> void:
	var inv := Game.inventory
	_clear_children(_grid)
	var bag := inv.backpack()
	_capacity.text = "Bag %d / %d   (%s)" % [inv.stacks.size(), inv.capacity(),
		bag.display_name if bag else "no backpack"]
	_selected = clampi(_selected, 0, maxi(inv.capacity() - 1, 0))
	for i in inv.capacity():
		var slot := _new_slot(_grid)
		if i < inv.stacks.size():
			slot.show_item(ItemLibrary.by_id(inv.stacks[i]["id"]), inv.stacks[i]["count"])
		else:
			slot.show_empty()
		slot.focus_entered.connect(_on_slot_focused.bind(i))
		slot.pressed.connect(_on_slot_pressed.bind(i))
	FocusPop.attach_all(_grid)
	if _page == Page.ITEMS and visible:
		_focus_selected_slot(_grid, _selected)
		_update_item_details()

func _new_slot(parent: Control) -> InventorySlot:
	var slot := slot_scene.instantiate() as InventorySlot
	parent.add_child(slot)
	if slot_styles.size() >= 3:
		slot.add_theme_stylebox_override(&"normal", slot_styles[0])
		slot.add_theme_stylebox_override(&"hover", slot_styles[1])
		slot.add_theme_stylebox_override(&"pressed", slot_styles[2])
		slot.set_meta(FocusPop.LOOKS_META, slot_styles)
	return slot

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _focus_selected_slot(grid: GridContainer, index: int) -> void:
	if grid.get_child_count() == 0:
		return
	var slot := grid.get_child(clampi(index, 0, grid.get_child_count() - 1)) as Control
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
	_use_button.visible = false
	_drop_button.visible = false
	_clear_assign()
	if _selected >= stacks.size():
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
	if item.is_usable():
		_set_assign(item.id, [3, 4, 5])

func _use_selected() -> void:
	if _selected >= Game.inventory.stacks.size():
		return
	var msg := Game.inventory.use(_selected)
	refresh()
	_message.text = msg

func _drop_selected() -> void:
	if _selected >= Game.inventory.stacks.size():
		return
	var item := ItemLibrary.by_id(Game.inventory.stacks[_selected]["id"])
	if item == null or not item.can_drop():
		return
	Game.inventory.remove_at(_selected, 1)
	refresh()
	_message.text = "Dropped %s." % item.display_name

# ---------------------------------------------------------------- hotbar assignment

func _clear_assign() -> void:
	_assign_label.visible = false
	_clear_children(_assign_row)

## Buttons to put `id` on one of the hotbar `slots` (indices), plus Unequip
## if it's already on the bar.
func _set_assign(id: StringName, slots: Array) -> void:
	_clear_children(_assign_row)
	_assign_label.visible = true
	var current := Game.hotbar.slot_of(id)
	for slot in slots:
		var b := Button.new()
		b.text = ("✓ " if slot == current else "") + str(slot + 1)
		b.add_theme_font_size_override(&"font_size", 40)
		b.pressed.connect(_assign.bind(id, slot))
		_assign_row.add_child(b)
	if current != -1:
		var u := Button.new()
		u.text = "Unequip"
		u.add_theme_font_size_override(&"font_size", 36)
		u.pressed.connect(_unassign.bind(current, id))
		_assign_row.add_child(u)
	FocusPop.attach_all(_assign_row)

func _assign(id: StringName, slot: int) -> void:
	if Game.hotbar.assign(slot, id):
		_message.text = "Equipped to hotbar slot %d." % (slot + 1)
		_redisplay_details()

func _unassign(slot: int, _id: StringName) -> void:
	Game.hotbar.clear(slot)
	_message.text = "Removed from the hotbar."
	_redisplay_details()

func _redisplay_details() -> void:
	var keep := _message.text
	match _page:
		Page.ITEMS: _update_item_details()
		Page.ABILITIES: _update_ability_details()
	_message.text = keep

# ---------------------------------------------------------------- abilities

func _build_abilities() -> void:
	_clear_children(_ability_grid)
	var known := Game.hotbar.known
	_selected_ability = clampi(_selected_ability, 0, maxi(known.size() - 1, 0))
	for i in known.size():
		var slot := _new_slot(_ability_grid)
		slot.show_ability(AbilityLibrary.by_id(known[i]))
		slot.focus_entered.connect(_on_ability_focused.bind(i))
	FocusPop.attach_all(_ability_grid)
	if _page == Page.ABILITIES and visible:
		_focus_selected_slot(_ability_grid, _selected_ability)
		_update_ability_details()

func _on_ability_focused(index: int) -> void:
	_selected_ability = index
	_message.text = ""
	_update_ability_details()

func _update_ability_details() -> void:
	_use_button.visible = false
	_drop_button.visible = false
	_clear_assign()
	var known := Game.hotbar.known
	if _selected_ability >= known.size():
		_detail_name.text = "No abilities yet"
		_detail_kind.text = ""
		_detail_text.text = "Learn abilities from shops."
		return
	var a := AbilityLibrary.by_id(known[_selected_ability])
	_detail_name.text = a.display_name
	_detail_kind.text = "Ability   Cooldown %ds" % int(a.cooldown)
	_detail_text.text = a.description
	_set_assign(a.id, [0, 1, 2])

# ---------------------------------------------------------------- gear

func _build_gear() -> void:
	var s := Game.stats
	_fill_gear(_armor_list, s.owned_armors, s.equipped_armor)
	_fill_gear(_shield_list, s.owned_shields, s.equipped_shield)
	_fill_gear(_weapon_list, s.owned_weapons, s.equipped_weapon)
	FocusPop.attach_all(_gear_list_root())
	if _page == Page.GEAR and visible:
		_focus_gear.call_deferred()

func _gear_list_root() -> Node:
	return _pages[Page.GEAR]

func _fill_gear(list: VBoxContainer, owned: Array, equipped: EquipmentData) -> void:
	_clear_children(list)
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
	_clear_assign()
	_detail_name.text = item.display_name
	var equipped: EquipmentData = Game.stats.equipped_armor if item is ArmorData \
		else (Game.stats.equipped_shield if item is ShieldData else Game.stats.equipped_weapon)
	_detail_kind.text = "Equipped" if equipped != null and equipped.id == item.id else "Press to equip"
	_detail_text.text = _gear_text(item)

func _gear_text(item: EquipmentData) -> String:
	var stat := ""
	if item is ArmorData: stat = "Armor: +%d max HP" % item.hp_bonus
	elif item is ShieldData: stat = "Shield: +%d max shield" % item.shield_bonus
	elif item is WeaponData: stat = "Weapon: +%d damage" % item.damage_bonus
	var flavor := item.flavor()
	return stat if flavor == "" else flavor + "\n\n" + stat

func _equip(item: EquipmentData) -> void:
	Game.stats.equip(item)   # emits stats_changed -> refresh()
	_message.text = "Equipped %s." % item.display_name
