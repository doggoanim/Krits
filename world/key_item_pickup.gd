class_name KeyItemPickup
extends Interactable
## A one-time pickup of a key item lying in the world (the water spirits at the
## bottom of the well). Press interact to take it; the pickup is remembered in
## a story flag, so it stays gone, and the game saves right away so a quest
## item can't be lost to a closed window. Build it like any Interactable: a
## CollisionShape3D plus whatever visual you like as children.

@export var item_id: StringName = &""
@export var count := 1
## Unique per pickup; "picked_<pickup_id>" is the flag that remembers it.
@export var pickup_id: StringName = &""

func _ready() -> void:
	if Game.flag(_flag()):
		queue_free()
		return
	super()

func _flag() -> StringName:
	return StringName("picked_" + String(pickup_id))

func _can_interact() -> bool:
	return player != null and not player.dead and not Game.input_locked

func _interact() -> void:
	var item := ItemLibrary.by_id(item_id)
	if not Game.inventory.can_fit(item_id, count):
		return
	Game.set_flag(_flag())
	if item != null and item.important:
		# The "You got the ...!" fanfare hands it over (and saves) when its box closes.
		ItemGet.give(item_id, count, Game.save)
	else:
		Game.inventory.add(item_id, count)
		Events.notice.emit("Got %s!" % (item.display_name if item else String(item_id)))
		Game.save()
	queue_free()
