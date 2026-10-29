class_name ShopKeeper
extends Interactable
## A shop trigger: opens ShopMenu on interact, same range/prompt plumbing as
## NPC (see Interactable) but no dialogue — just the shop. Build it like NPC:
## a CollisionShape3D for its body plus whatever visual you want as children.

## Ids of what this shop sells (equipment, abilities, items, backpacks — the
## same ids the libraries use, e.g. "round_shield", "guard_up", "health_potion",
## "small_backpack"). Leave empty to sell everything that has a price.
@export var stock: PackedStringArray = PackedStringArray()

func _can_interact() -> bool:
	return (player != null and not player.dead
		and player.machine.current_name == &"Ground"
		and MenuBase.open_menu == null
		and (DialogueBox.instance == null or not DialogueBox.instance.is_active()))

func _interact() -> void:
	if ShopMenu.instance:
		ShopMenu.instance.open_shop(stock)
