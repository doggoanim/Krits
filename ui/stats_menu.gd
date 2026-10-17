class_name StatsMenu
extends MenuBase

func _init() -> void:
	toggle_action = &"menu_stats"

func refresh() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var s := Game.stats
	title("Level %d  —  %d points" % [s.level, s.points])
	_row("HP", &"hp", "%d" % s.max_hp())
	_row("Shield", &"shield", "%d" % s.max_shield())
	_row("Damage", &"damage", "%d" % s.damage())

func _row(label: String, stat: StringName, value: String) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = "%s: %s" % [label, value]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := Button.new()
	b.text = "+"
	b.disabled = Game.stats.points <= 0
	b.pressed.connect(func(): Game.stats.spend_point(stat))
	h.add_child(b)
	content.add_child(h)
