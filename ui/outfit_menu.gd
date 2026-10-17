class_name OutfitMenu
extends MenuBase

func _init() -> void:
	toggle_action = &"menu_outfit"

func refresh() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	title("Outfits")
	for o in OutfitLibrary.all():
		if o.id in Game.unlocked_outfits:
			var b := Button.new()
			b.text = o.display_name + ("  (equipped)" if o.id == Game.outfit else "")
			b.pressed.connect(func():
				Game.set_outfit(o.id)
				refresh())
			content.add_child(b)
