class_name ShopMenu
extends MenuBase
## Buy/equip armor (HP), shields (Shield) and weapons (Damage) with gold
## earned from fights (see Arena._end()/PlayerStats.add_gold()). No
## toggle_action — opened by a ShopKeeper in the world, not a hotkey (see
## MenuBase._unhandled_input()'s empty-toggle_action guard).
##
## Items come from EquipmentLibrary's static catalog (all_armors()/
## all_shields()/all_weapons()) — add a new one there and it shows up here
## for free, same as EnemyLibrary feeding DebugTools' fight shortcuts.

static var instance: ShopMenu

func _ready() -> void:
	super._ready()
	instance = self

func refresh() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var s := Game.stats
	title("Gold: %d" % s.gold)
	_section("Armor (HP)", EquipmentLibrary.all_armors(), s.equipped_armor)
	_section("Shields (Shield)", EquipmentLibrary.all_shields(), s.equipped_shield)
	_section("Weapons (Damage)", EquipmentLibrary.all_weapons(), s.equipped_weapon)
	_ability_section()
	_backpack_section()
	_supplies_section()
	_sell_section()

func _section(heading: String, items: Array, equipped: EquipmentData) -> void:
	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 18)
	content.add_child(h)
	for item in items:
		_row(item, equipped != null and equipped.id == item.id)

func _row(item: EquipmentData, is_equipped: bool) -> void:
	var s := Game.stats
	var is_owned := s.is_owned(item)
	var h := HBoxContainer.new()

	var bonus := _bonus_text(item)
	var l := Label.new()
	l.text = "%s%s  —  %s" % [item.display_name, bonus, ("owned" if is_owned else "%dg" % item.price)]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)

	var b := Button.new()
	if is_equipped:
		if item is WeaponData:
			b.text = "Equipped"
			b.disabled = true
		else:
			b.text = "Take off"
			b.pressed.connect(func():
				s.unequip(item)
				refresh())
	else:
		b.text = "Equip" if is_owned else "Buy"
		b.disabled = not is_owned and item.price > s.gold
		b.pressed.connect(func():
			s.buy(item)
			refresh())
	h.add_child(b)
	content.add_child(h)

## A short "+N stat" suffix so the list reads at a glance, without needing a
## separate column per possible stat (each item only ever has the one that
## matches its own slot).
func _bonus_text(item: EquipmentData) -> String:
	if item is ArmorData: return "  (+%d HP)" % item.hp_bonus
	if item is ShieldData: return "  (+%d Shield)" % item.shield_bonus
	if item is WeaponData: return "  (+%d Dmg)" % item.damage_bonus
	return ""

# ---------------------------------------------------------------- bag, supplies, selling

func _heading(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 18)
	content.add_child(h)

func _add_row(text: String, buttons: Array) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for b in buttons:
		h.add_child(b)
	content.add_child(h)

func _button(text: String, disabled: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(func():
		action.call()
		refresh())
	return b

## Backpacks: each one replaces the last (they don't stack), so only
## upgrades can be bought.
func _backpack_section() -> void:
	var inv := Game.inventory
	_heading("Backpacks (Bag slots: %d)" % inv.capacity())
	var current := inv.backpack()
	for bag in ItemLibrary.all_backpacks():
		var owned := current != null and current.id == bag.id
		var upgrade := bag.slots > (current.slots if current else 0)
		var label := "%s  (+%d slots)  —  %s" % [bag.display_name, bag.slots, "owned" if owned else "%dg" % bag.price]
		var b := _button("Owned" if owned else ("Buy" if upgrade else "—"),
			owned or not upgrade or bag.price > Game.stats.gold, func(): inv.buy_backpack(bag))
		_add_row(label, [b])

func _supplies_section() -> void:
	var inv := Game.inventory
	_heading("Supplies")
	for item in ItemLibrary.all_items():
		if item.buy_price <= 0:
			continue
		var label := "%s  —  %dg   (have %d)" % [item.display_name, item.buy_price, inv.count_of(item.id)]
		var b := _button("Bag full" if not inv.can_fit(item.id, 1) else "Buy",
			item.buy_price > Game.stats.gold or not inv.can_fit(item.id, 1), func(): inv.buy_item(item))
		_add_row(label, [b])

func _sell_section() -> void:
	var inv := Game.inventory
	var sellable: Array[ItemData] = []
	for item in ItemLibrary.all_items():
		if item.sell_price > 0 and inv.has(item.id):
			sellable.append(item)
	if sellable.is_empty():
		return
	_heading("Sell")
	for item in sellable:
		var n := inv.count_of(item.id)
		_add_row("%s x%d  —  %dg each" % [item.display_name, n, item.sell_price], [
			_button("Sell 1", false, func(): inv.sell_item(item.id, 1)),
			_button("Sell all", n < 2, func(): inv.sell_item(item.id, n)),
		])

## Abilities: bought once, then equipped to hotbar slots 1-3 from the
## inventory's Abilities tab. Free starter abilities (price 0) aren't listed.
func _ability_section() -> void:
	_heading("Abilities")
	for a in AbilityLibrary.all_abilities():
		if a.price <= 0:
			continue
		var known := Game.hotbar.knows(a.id)
		var label := "%s  —  %s" % [a.display_name, "learned" if known else "%dg" % a.price]
		var b := _button("Learned" if known else "Buy", known or a.price > Game.stats.gold,
			func(): _buy_ability(a))
		_add_row(label, [b])

func _buy_ability(a: AbilityData) -> void:
	if Game.stats.gold < a.price or Game.hotbar.knows(a.id):
		return
	Game.stats.gold -= a.price
	Events.stats_changed.emit()
	Game.hotbar.learn(a.id)
