class_name InventoryMenu
extends MenuBase
## The bag screen (hotkey: "menu_inventory", default Tab). Four tabs:
##   Items     — a grid of slots (Game.inventory; capacity grows with
##               backpacks). Pick one to read about it; Use / Drop, and put
##               consumables on hotbar slots 4-6. Key items sit in their own
##               section below the bag (no slots used, can't be sold/dropped).
##   Gear      — every armor/shield/weapon you own; pick one to equip it.
##   Abilities — the abilities you know; put them on hotbar slots 1-3.
##   Quests    — the quest log: active quests (main first) and finished ones.
## The hotbar itself is shown along the bottom (display only here — the
## number keys use it in the game, see HotbarBar). Layout and art live in
## inventory_menu.tscn; this script fills in the dynamic parts.

enum Page { ITEMS, GEAR, ABILITIES, QUESTS }

@export var slot_scene: PackedScene
@export var slot_styles: Array[StyleBox] = []   ## nine-sliced plates: normal, hover, pressed

@onready var _gold: Label = %GoldLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _tabs: Array[Button] = [%ItemsTab, %GearTab, %AbilitiesTab, %QuestsTab]
@onready var _pages: Array[Control] = [%ItemsPage, %GearPage, %AbilitiesPage, %QuestsPage]
@onready var _capacity: Label = %CapacityLabel
@onready var _grid: GridContainer = %Grid
@onready var _key_grid: GridContainer = %KeyGrid
@onready var _key_empty: Label = %KeyEmpty
@onready var _quest_list: VBoxContainer = %QuestList
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
var _selected_quest: StringName = &""   ## id of the focused quest (restored after a rebuild)
var _gear_focus: StringName = &""   ## id of the focused gear button (restored after a rebuild)

func _init() -> void:
	toggle_action = &"menu_inventory"

func _ready() -> void:
	super()
	for i in _tabs.size():
		_tabs[i].pressed.connect(_show_page.bind(i))
	Events.quests_changed.connect(_on_quests_changed)
	_use_button.pressed.connect(_on_use_pressed)
	_drop_button.pressed.connect(_drop_selected)

func _on_quests_changed() -> void:
	if visible:
		refresh()

## The base class frees everything under Content on open; here Content holds
## the fixed layout from the scene, so leave it alone.
func _clear() -> void:
	pass

## Tab is both the open key and a UI focus key, and a focused control would
## swallow it before MenuBase's _unhandled_input ever saw it — so while open,
## catch the toggle here, ahead of GUI focus handling.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(toggle_action):
		close()
		get_viewport().set_input_as_handled()
		return
	# With an item/ability selected, its hotbar number key assigns it directly
	# (same as clicking that number's button below the details).
	if _assign_id != &"" and event is InputEventKey and not (event as InputEventKey).echo:
		for slot: int in _assign_slots:
			if event.is_action_pressed(StringName("hotbar_%d" % (slot + 1))):
				_assign(_assign_id, slot)
				get_viewport().set_input_as_handled()
				return

func open() -> void:
	super()
	if open_menu != self:
		return
	_message.text = ""
	_show_page(Page.ITEMS)

func refresh() -> void:
	var s := Game.stats
	_gold.text = "Gold: %d" % s.gold
	_stats_label.text = "HP %d/%d   Shield %d/%d   Damage %s" % [s.hp, s.max_hp(), s.shield, s.max_shield(), String.num(s.damage())]
	_build_items()
	_build_gear()
	_build_abilities()
	_build_quests()

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
		Page.QUESTS:
			_focus_quest.call_deferred()

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
	FocusPop.attach_all(_grid, true)
	_build_key_items()
	if _page == Page.ITEMS and visible:
		_focus_selected_slot(_grid, _selected)
		_update_item_details()

## The key-item section under the bag: one slot per key item, no capacity use.
func _build_key_items() -> void:
	_clear_children(_key_grid)
	var ids: Array = Game.inventory.key_items.keys()
	_key_empty.visible = ids.is_empty()
	for id: StringName in ids:
		var item := ItemLibrary.by_id(id)
		if item == null:
			continue
		var slot := _new_slot(_key_grid)
		slot.show_item(item, int(Game.inventory.key_items[id]))
		slot.focus_entered.connect(_on_key_focused.bind(item))
	FocusPop.attach_all(_key_grid, true)

func _on_key_focused(item: ItemData) -> void:
	_message.text = ""
	_use_button.visible = false
	_drop_button.visible = false
	_clear_assign()
	_detail_name.text = item.display_name
	_detail_kind.text = item.category_name()
	_detail_text.text = item.description

func _new_slot(parent: Control) -> InventorySlot:
	var slot := slot_scene.instantiate() as InventorySlot
	parent.add_child(slot)
	InventorySlot.apply_styles(slot, slot_styles)
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
	_use_button.text = "Use"
	_use_button.disabled = false
	_use_button.visible = item.is_usable()
	_drop_button.visible = item.can_drop()
	_drop_button.text = "Drop 1"
	if item.is_usable():
		_set_assign(item.id, [3, 4, 5])

var _gear_selected: EquipmentData   ## the gear entry currently focused on the Gear page

## The one action button: Use on the Items page, Equip/Take off on Gear.
func _on_use_pressed() -> void:
	if _page == Page.GEAR:
		if _gear_selected == null:
			return
		var s := Game.stats
		var worn: EquipmentData = s.equipped_armor if _gear_selected is ArmorData \
			else (s.equipped_shield if _gear_selected is ShieldData else s.equipped_weapon)
		_toggle_gear(_gear_selected, worn != null and worn.id == _gear_selected.id)
	else:
		_use_selected()

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

var _assign_id: StringName = &""   ## what the number keys would assign right now (see _input())
var _assign_slots: Array = []

func _clear_assign() -> void:
	_assign_id = &""
	_assign_slots = []
	_assign_label.visible = false
	_clear_children(_assign_row)

## Buttons to put `id` on one of the hotbar `slots` (indices), plus Unequip
## if it's already on the bar.
func _set_assign(id: StringName, slots: Array) -> void:
	_clear_children(_assign_row)
	_assign_label.visible = true
	_assign_id = id
	_assign_slots = slots
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
	FocusPop.attach_all(_assign_row, true)

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
	FocusPop.attach_all(_ability_grid, true)
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
	_detail_kind.text = "Ability   Cooldown %ds   Stamina %d" % [int(a.cooldown), int(a.stamina_cost)]
	_detail_text.text = a.description
	_set_assign(a.id, [0, 1, 2])

# ---------------------------------------------------------------- quests

func _build_quests() -> void:
	_clear_children(_quest_list)
	var quest_log := Game.quests
	var entries: Array[QuestData] = []
	entries.append_array(quest_log.active_quests())
	entries.append_array(quest_log.completed_quests())
	for q in entries:
		var done := quest_log.is_complete(q.id)
		var b := Button.new()
		b.text = ("✓ " if done else ("★ " if q.is_main else "")) + q.title
		b.add_theme_font_size_override(&"font_size", 40)
		b.set_meta(GEAR_ID_META, q.id)   # reused meta key: the id this button stands for
		b.focus_entered.connect(_on_quest_focused.bind(q))
		_quest_list.add_child(b)
	FocusPop.attach_all(_quest_list, true)
	if _page == Page.QUESTS and visible:
		_focus_quest.call_deferred()

func _focus_quest() -> void:
	var first: Control = null
	for b in _quest_list.get_children():
		first = first if first else b as Control
		if b.get_meta(GEAR_ID_META) == _selected_quest:
			(b as Control).grab_focus()
			return
	if first:
		first.grab_focus()
	else:
		_show_no_quests()

func _show_no_quests() -> void:
	_use_button.visible = false
	_drop_button.visible = false
	_clear_assign()
	_detail_name.text = "No quests"
	_detail_kind.text = ""
	_detail_text.text = "Nothing to do yet. Talk to people."

func _on_quest_focused(q: QuestData) -> void:
	_selected_quest = q.id
	_message.text = ""
	_use_button.visible = false
	_drop_button.visible = false
	_clear_assign()
	var done := Game.quests.is_complete(q.id)
	_detail_name.text = q.title
	_detail_kind.text = "Completed" if done else ("Main quest" if q.is_main else "Side quest")
	var text := q.description
	text += "\n\n"
	for o in q.objectives:
		var p := o.progress()
		var mark := "☑" if o.is_done() else "☐"
		var count := "  (%d/%d)" % [int(p["have"]), int(p["need"])] if int(p["need"]) > 1 else ""
		text += "%s %s%s\n" % [mark, o.text, count]
	if q.reward_gold > 0 or not q.reward_items.is_empty():
		text += "\nReward:"
		if q.reward_gold > 0:
			text += " %dg" % q.reward_gold
		for item_id: StringName in q.reward_items:
			var item := ItemLibrary.by_id(item_id)
			text += "  %s x%d" % [item.display_name if item else String(item_id), int(q.reward_items[item_id])]
	_detail_text.text = text

# ---------------------------------------------------------------- gear

func _build_gear() -> void:
	var s := Game.stats
	_fill_gear(_armor_list, s.owned_armors, s.equipped_armor)
	_fill_gear(_shield_list, s.owned_shields, s.equipped_shield)
	_fill_gear(_weapon_list, s.owned_weapons, s.equipped_weapon)
	FocusPop.attach_all(_gear_list_root(), true)
	if _page == Page.GEAR and visible:
		_focus_gear.call_deferred()

func _gear_list_root() -> Node:
	return _pages[Page.GEAR]

func _fill_gear(list: VBoxContainer, owned: Array, equipped: EquipmentData) -> void:
	_clear_children(list)
	var items: Array[EquipmentData] = []
	for id in owned:
		var found := EquipmentLibrary.by_id(id)
		if found != null:
			items.append(found)
	if not items.is_empty() and items[0] is WeaponData:   # armor/shields keep their buy order (sort_custom isn't stable)
		items.sort_custom(EquipmentLibrary.is_listed_before)
	for item in items:
		var b := Button.new()
		var is_equipped := equipped != null and equipped.id == item.id
		b.text = ("★ " if is_equipped else "") + item.display_name
		b.add_theme_font_size_override(&"font_size", 40)
		b.set_meta(GEAR_ID_META, item.id)
		b.focus_entered.connect(_on_gear_focused.bind(item))
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
	_gear_selected = item
	_drop_button.visible = false
	_clear_assign()
	_detail_name.text = item.display_name
	var equipped: EquipmentData = Game.stats.equipped_armor if item is ArmorData \
		else (Game.stats.equipped_shield if item is ShieldData else Game.stats.equipped_weapon)
	var worn := equipped != null and equipped.id == item.id
	_detail_kind.text = "Equipped" if worn else "Not equipped"
	_detail_text.text = _gear_text(item)
	# Equipping is a button, not a click on the list entry. Worn armor/shield
	# can be taken off; a worn weapon has nothing to do.
	_use_button.visible = true
	if worn and not (item is ArmorData or item is ShieldData):
		_use_button.text = "Equipped"
		_use_button.disabled = true
	else:
		_use_button.text = "Take off" if worn else "Equip"
		_use_button.disabled = false

func _gear_text(item: EquipmentData) -> String:
	var stat := EquipmentLibrary.stat_line(item)
	var flavor := item.flavor()
	return stat if flavor == "" else flavor + "\n\n" + stat

## The Equip button: worn armor/shield comes off; anything else equips.
func _toggle_gear(item: EquipmentData, is_equipped: bool) -> void:
	if is_equipped and (item is ArmorData or item is ShieldData):
		Game.stats.unequip(item)   # emits stats_changed -> refresh()
		_message.text = "Took off %s." % item.display_name
	else:
		_equip(item)

func _equip(item: EquipmentData) -> void:
	Game.stats.equip(item)   # emits stats_changed -> refresh()
	_message.text = "Equipped %s." % item.display_name
