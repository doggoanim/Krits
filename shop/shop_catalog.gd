class_name ShopCatalog
extends RefCounted
## Turns the game's libraries into ShopOffers. A shop's `stock` (a list of ids
## set on its ShopKeeper) limits what it carries; an empty stock means
## "everything that's for sale". Free starter gear/abilities (price 0) are
## never listed. To make something purchasable, just give it a price in its
## library — no shop code to touch.

static func buy_offers(stock: PackedStringArray) -> Array[ShopOffer]:
	var out: Array[ShopOffer] = []
	for item in EquipmentLibrary.all_armors():
		_add_gear(out, stock, item)
	for item in EquipmentLibrary.all_shields():
		_add_gear(out, stock, item)
	for item in EquipmentLibrary.all_weapons():
		_add_gear(out, stock, item)
	for a in AbilityLibrary.all_abilities():
		if a.price > 0 and _stocked(stock, a.id):
			out.append(_ability(a))
	for bag in ItemLibrary.all_backpacks():
		if _stocked(stock, bag.id):
			out.append(_backpack(bag))
	for item in ItemLibrary.all_items():
		if item.buy_price > 0 and _stocked(stock, item.id):
			out.append(_supply(item))
	return out

## The player's sellable items, one offer per kind of item (stacks merged).
static func sell_offers() -> Array[ShopOffer]:
	var out: Array[ShopOffer] = []
	for item in ItemLibrary.all_items():
		var n := Game.inventory.count_of(item.id)
		if item.sell_price > 0 and n > 0 and item.category != ItemData.Category.KEY:
			var o := _supply(item)
			o.tab = ShopOffer.Tab.SELL
			o.price = item.sell_price
			o.count = n
			out.append(o)
	return out

static func _add_gear(out: Array[ShopOffer], stock: PackedStringArray, item: EquipmentData) -> void:
	if item.price > 0 and _stocked(stock, item.id):
		out.append(_gear(item))

static func _stocked(stock: PackedStringArray, id: StringName) -> bool:
	return stock.is_empty() or String(id) in stock

static func _gear(item: EquipmentData) -> ShopOffer:
	var o := ShopOffer.new()
	o.tab = ShopOffer.Tab.GEAR
	o.kind = ShopOffer.Kind.EQUIPMENT
	o.id = item.id
	o.data = item
	o.display_name = item.display_name
	o.price = item.price
	o.kind_text = EquipmentLibrary.stat_line(item)
	o.description = item.flavor()
	o.color = Color(0.45, 0.65, 0.95) if item is ArmorData \
		else (Color(0.85, 0.7, 0.4) if item is ShieldData else Color(0.9, 0.45, 0.4))
	return o

static func _ability(a: AbilityData) -> ShopOffer:
	var o := ShopOffer.new()
	o.tab = ShopOffer.Tab.ABILITIES
	o.kind = ShopOffer.Kind.ABILITY
	o.id = a.id
	o.data = a
	o.display_name = a.display_name
	o.price = a.price
	o.kind_text = "Ability   Cooldown %ds" % int(a.cooldown)
	o.description = a.description
	o.icon = a.icon
	o.color = a.color
	return o

static func _backpack(bag: BackpackData) -> ShopOffer:
	var o := ShopOffer.new()
	o.tab = ShopOffer.Tab.SUPPLIES
	o.kind = ShopOffer.Kind.BACKPACK
	o.id = bag.id
	o.data = bag
	o.display_name = bag.display_name
	o.price = bag.price
	o.kind_text = "Backpack   +%d bag slots" % bag.slots
	o.description = "Replaces your current backpack."
	o.color = Color(0.7, 0.55, 0.35)
	return o

static func _supply(item: ItemData) -> ShopOffer:
	var o := ShopOffer.new()
	o.tab = ShopOffer.Tab.SUPPLIES
	o.kind = ShopOffer.Kind.ITEM
	o.id = item.id
	o.data = item
	o.display_name = item.display_name
	o.price = item.buy_price
	o.kind_text = item.category_name()
	o.description = item.description
	o.icon = item.icon
	o.color = item.color
	return o
