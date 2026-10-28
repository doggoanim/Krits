class_name TravelMenu
extends MenuBase

var is_in_combat := func() -> bool: return false

func _init() -> void:
	toggle_action = &"menu_travel"

func can_open() -> bool:
	if is_in_combat.call():
		Events.notice.emit("Can't fast travel during a fight.")
		return false
	return true

func refresh() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	title("Fast Travel")
	var any := false
	for n in get_tree().get_nodes_in_group(&"spawnpoints"):
		var sp := n as Spawnpoint
		if sp.is_unlocked():
			any = true
			var b := Button.new()
			b.text = sp.display_name
			b.pressed.connect(func():
				close()
				Events.fast_travel_requested.emit(sp.spawn_id))
			content.add_child(b)
	if not any:
		var l := Label.new()
		l.text = "No spawnpoints discovered yet."
		content.add_child(l)
