class_name ShopMenu
extends MenuBase
## The shop screen, laid out like the inventory: tabs along the top (Gear /
## Abilities / Supplies / Sell), a grid of slots on the left and a details
## panel with the Buy button on the right. Scene and art: shop_menu.tscn.
##
## What a shop sells comes from its ShopKeeper's `stock` (ids; empty = the
## whole catalog) via ShopCatalog — this script only shows ShopOffers and acts
## on them. Opened by ShopKeeper with open_shop(); no hotkey (Esc closes).
##
## Gold only comes from selling items now (enemies don't pay), so the Sell tab
## lists whatever sellable drops are in the bag.

static var instance: ShopMenu

const MAX_QTY := 99

@export var slot_scene: PackedScene
@export var slot_styles: Array[StyleBox] = []   ## nine-sliced plates: normal, hover, pressed

@onready var _gold: Label = %GoldLabel
@onready var _tabs: Array[Button] = [%GearTab, %AbilitiesTab, %SuppliesTab, %SellTab]   # index == ShopOffer.Tab
@onready var _grid: GridContainer = %Grid
@onready var _name: Label = %DetailName
@onready var _kind: Label = %DetailKind
@onready var _text: Label = %DetailText
@onready var _price: Label = %PriceLabel
@onready var _qty_row: HBoxContainer = %QuantityRow
@onready var _qty_label: Label = %QtyLabel
@onready var _minus: Button = %MinusButton
@onready var _plus: Button = %PlusButton
@onready var _max: Button = %MaxButton
@onready var _message: Label = %Message
@onready var _action: Button = %ActionButton

var _stock := PackedStringArray()
var _buy_offers: Array[ShopOffer] = []   ## everything this shop sells, all tabs
var _offers: Array[ShopOffer] = []       ## what the current tab shows
var _tab := ShopOffer.Tab.GEAR
var _selected := 0
var _qty := 1
var _focus_restored := false   ## set when a rebuild re-focuses the selected slot (not a real selection change)

func _ready() -> void:
	super()
	instance = self
	for i in _tabs.size():
		_tabs[i].pressed.connect(_show_tab.bind(i))
	_minus.pressed.connect(_change_qty.bind(-1))
	_plus.pressed.connect(_change_qty.bind(1))
	_max.pressed.connect(_change_qty.bind(MAX_QTY))
	_action.pressed.connect(_do_action)
	FocusPop.attach_all(self, true)

## The inventory key (Tab) also closes the shop. Caught in _input, ahead of GUI
## focus handling, since Tab is a focus-navigation key too.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"menu_inventory"):
		close()
		get_viewport().set_input_as_handled()

## Content holds the fixed layout from the scene — nothing to clear on open.
func _clear() -> void:
	pass

## Open this shop with `stock` (ids it carries; empty = everything for sale).
func open_shop(stock := PackedStringArray()) -> void:
	_stock = stock
	open()

func open() -> void:
	super()
	if open_menu != self:
		return
	_buy_offers = ShopCatalog.buy_offers(_stock)
	_message.text = ""
	_selected = 0
	_show_tab(_first_tab())

func refresh() -> void:
	_gold.text = "Gold: %d" % Game.stats.gold
	for t in [ShopOffer.Tab.GEAR, ShopOffer.Tab.ABILITIES, ShopOffer.Tab.SUPPLIES]:
		_tabs[t].visible = not _offers_for(t).is_empty()
	_offers = _offers_for(_tab)
	_selected = clampi(_selected, 0, maxi(_offers.size() - 1, 0))
	_build_grid()
	_update_details()

# ---------------------------------------------------------------- tabs

func _first_tab() -> ShopOffer.Tab:
	for t in [ShopOffer.Tab.GEAR, ShopOffer.Tab.ABILITIES, ShopOffer.Tab.SUPPLIES]:
		if not _offers_for(t).is_empty():
			return t as ShopOffer.Tab
	return ShopOffer.Tab.SELL

func _offers_for(tab: ShopOffer.Tab) -> Array[ShopOffer]:
	if tab == ShopOffer.Tab.SELL:
		return ShopCatalog.sell_offers()
	var out: Array[ShopOffer] = []
	for o in _buy_offers:
		if o.tab == tab:
			out.append(o)
	return out

func _show_tab(tab: int) -> void:
	_tab = tab as ShopOffer.Tab
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(i == tab)
	_selected = 0
	_qty = 1
	_message.text = ""
	refresh()

# ---------------------------------------------------------------- grid

func _build_grid() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for i in _offers.size():
		var o := _offers[i]
		var slot := slot_scene.instantiate() as InventorySlot
		_grid.add_child(slot)
		InventorySlot.apply_styles(slot, slot_styles)
		var count_text := "x%d" % o.count if o.tab == ShopOffer.Tab.SELL and o.count > 1 else ""
		slot.show_custom(o.icon, o.display_name.left(1), o.color, count_text)
		slot.set_dim(o.tab != ShopOffer.Tab.SELL and o.is_owned())
		slot.focus_entered.connect(_on_slot_focused.bind(i))
		slot.pressed.connect(_do_action)
	FocusPop.attach_all(_grid, true)
	if visible and not _offers.is_empty():
		_focus_restored = true
		(_grid.get_child(_selected) as Control).grab_focus.call_deferred()

func _on_slot_focused(index: int) -> void:
	if index == _selected and _focus_restored:
		_focus_restored = false   # a rebuild putting focus back — keep the message and quantity
		return
	_selected = index
	_qty = 1
	_message.text = ""
	_update_details()

func _current() -> ShopOffer:
	return _offers[_selected] if _selected < _offers.size() else null

# ---------------------------------------------------------------- details

func _update_details() -> void:
	var o := _current()
	if o == null:
		_name.text = "Nothing to sell" if _tab == ShopOffer.Tab.SELL else "Nothing here"
		_kind.text = ""
		_text.text = "Monster drops and materials you pick up can be sold here." if _tab == ShopOffer.Tab.SELL else ""
		_price.text = ""
		_qty_row.visible = false
		_set_action("—", true)
		return
	_name.text = o.display_name
	_kind.text = o.kind_text
	_text.text = o.description
	_qty_row.visible = o.has_quantity()
	_qty = clampi(_qty, 1, maxi(_max_qty(o), 1))
	_qty_label.text = str(_qty)
	_minus.disabled = _qty <= 1
	_plus.disabled = _qty >= _max_qty(o)
	_max.disabled = _plus.disabled
	match o.tab:
		ShopOffer.Tab.SELL:
			_price.text = "+%dg" % (o.price * _qty)
			_set_action("Sell x%d" % _qty, false)
		_:
			_update_buy_details(o)

func _update_buy_details(o: ShopOffer) -> void:
	var total := o.price * (_qty if o.has_quantity() else 1)
	var gold := Game.stats.gold
	_price.text = "%dg" % total
	if o.is_owned():
		_price.text = ""
		match o.kind:
			ShopOffer.Kind.EQUIPMENT:
				if _is_equipped(o.data as EquipmentData):
					_set_action("Equipped", true)
				else:
					_set_action("Equip", false)
			ShopOffer.Kind.ABILITY:
				_set_action("Learned", true)
			_:
				_set_action("Owned", true)
		return
	if o.kind == ShopOffer.Kind.ITEM and not Game.inventory.can_fit(o.id, 1):
		_set_action("Bag full", true)
	elif total > gold:
		_set_action("Not enough gold", true)
	else:
		_set_action("Buy" if not o.has_quantity() else "Buy x%d" % _qty, false)

func _set_action(text: String, disabled: bool) -> void:
	_action.text = text
	_action.disabled = disabled

func _is_equipped(item: EquipmentData) -> bool:
	var worn: EquipmentData = Game.stats.equipped_armor if item is ArmorData \
		else (Game.stats.equipped_shield if item is ShieldData else Game.stats.equipped_weapon)
	return worn != null and worn.id == item.id

## How many the quantity selector may go up to for this offer.
func _max_qty(o: ShopOffer) -> int:
	if o.tab == ShopOffer.Tab.SELL:
		return o.count
	if not o.has_quantity():
		return 1
	var n := mini(MAX_QTY, int(Game.stats.gold / float(maxi(o.price, 1))))
	while n > 1 and not Game.inventory.can_fit(o.id, n):
		n -= 1
	return maxi(n, 1)

func _change_qty(delta: int) -> void:
	var o := _current()
	if o == null:
		return
	_qty = clampi(_qty + delta, 1, maxi(_max_qty(o), 1))
	_update_details()

# ---------------------------------------------------------------- buying / selling

func _do_action() -> void:
	var o := _current()
	if o == null or _action.disabled:
		return
	var s := Game.stats
	match o.kind:
		ShopOffer.Kind.EQUIPMENT:
			var item := o.data as EquipmentData
			if s.buy(item):   # buys if needed, then equips
				_message.text = "Equipped %s." % item.display_name
		ShopOffer.Kind.ABILITY:
			s.gold -= o.price
			Game.hotbar.learn(o.id)
			Events.stats_changed.emit()
			_message.text = "Learned %s!" % o.display_name
		ShopOffer.Kind.BACKPACK:
			if Game.inventory.buy_backpack(o.data as BackpackData):
				_message.text = "Bag upgraded."
		ShopOffer.Kind.ITEM:
			if o.tab == ShopOffer.Tab.SELL:
				var earned := Game.inventory.sell_item(o.id, _qty)
				_message.text = "Sold %d for %dg." % [_qty, earned]
			else:
				var bought := 0
				for i in _qty:
					if Game.inventory.buy_item(o.data as ItemData):
						bought += 1
				_message.text = "Bought %d %s." % [bought, o.display_name]
	_qty = 1
