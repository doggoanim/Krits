class_name QuestTracker
extends VBoxContainer
## The HUD's active-quest list: each quest's title with the objective to do
## next beneath it (with a count for collect-style steps). Main quest first.
## Rebuilt whenever the quest log changes (Events.quests_changed).

@export var max_quests := 4
@export var title_size := 28
@export var objective_size := 22
@export var title_color := Color(1.0, 0.9, 0.55)
@export var main_title_color := Color(1.0, 0.75, 0.3)
@export var objective_color := Color(1, 1, 1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.quests_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var shown := 0
	for q in Game.quests.active_quests():
		if shown >= max_quests:
			break
		shown += 1
		_add_line(("★ " if q.is_main else "") + q.title, title_size, main_title_color if q.is_main else title_color)
		var o := q.current_objective()
		if o != null and o.text != "":
			var p := o.progress()
			var count := "  (%d/%d)" % [int(p["have"]), int(p["need"])] if int(p["need"]) > 1 else ""
			_add_line("   " + o.text + count, objective_size, objective_color)

func _add_line(text: String, font_size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 8)
	add_child(l)
