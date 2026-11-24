class_name NpcStomp
extends StompZone
## Lets the player bounce off a character's head. Attached automatically by NPC and
## ShopKeeper (see NpcStomp.attach), so every character is stompable without scene edits.
##
## On a stomp (see StompZone): a squeak, the character squashes (talk_pop) and says a random
## line over their head (barks.cfg key `stomp`, with the [Stomp] section as the fallback for
## characters who have none of their own).

## Adds a stomp zone to `target` (once). Does nothing in the editor.
static func attach(target: Node3D) -> NpcStomp:
	if Engine.is_editor_hint() or target.get_node_or_null("Stomp") != null:
		return null
	var stomp := NpcStomp.new()
	stomp.name = "Stomp"
	target.add_child(stomp)
	return stomp

func _setup(box: AABB) -> void:
	squash = Vector2(1.25, 0.62)
	_ensure_barks(box.end.y)

## Characters without a Barks child get a silent one (chance 0) just for stomp lines.
func _ensure_barks(top: float) -> void:
	if _barks() != null:
		return
	var barks := NpcBarks.new()
	barks.name = "Barks"
	barks.chance = 0.0
	barks.height = top + 0.6
	_parent.add_child(barks)

func _barks() -> NpcBarks:
	for child in _parent.get_children():
		if child is NpcBarks:
			return child
	return null

func _react(_player: Player) -> void:
	# A big cartoon squash and stretch on the model (not the body, so the collision stays put).
	squash_pop((_parent as NPC).get_visual() if _parent is NPC else squash_target)
	var barks := _barks()
	if barks != null:
		var line := NpcBarks.pick_stomp_line(String(_parent.name))
		if not line.is_empty():
			barks.say(line)
