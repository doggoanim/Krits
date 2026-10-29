class_name ShopOffer
extends RefCounted
## One line of a shop: something to buy (or, in the Sell tab, a stack of the
## player's own items to sell). Pure data — ShopCatalog builds them and
## ShopMenu shows and acts on them.

enum Tab { GEAR, ABILITIES, SUPPLIES, SELL }
enum Kind { EQUIPMENT, ABILITY, ITEM, BACKPACK }

var tab := Tab.GEAR
var kind := Kind.ITEM
var id: StringName = &""
var display_name := ""
var kind_text := ""        ## small line under the name ("Armor", "Consumable"...)
var description := ""
var price := 0             ## buy price, or sell price per unit in the Sell tab
var count := 0             ## Sell tab: how many of it the player has
var data: Resource         ## the EquipmentData / AbilityData / ItemData / BackpackData
var icon: Texture2D
var color := Color.WHITE

## Supplies and Sell are bought/sold in quantities; gear, abilities and
## backpacks are one-offs.
func has_quantity() -> bool:
	return tab == Tab.SELL or (tab == Tab.SUPPLIES and kind == Kind.ITEM)

## True once there's nothing left to buy here (already owned/learned/outgrown).
func is_owned() -> bool:
	match kind:
		Kind.EQUIPMENT:
			return Game.stats.is_owned(data as EquipmentData)
		Kind.ABILITY:
			return Game.hotbar.knows(id)
		Kind.BACKPACK:
			var bag := data as BackpackData
			var cur := Game.inventory.backpack()
			return bag.slots <= (cur.slots if cur else 0)
	return false
