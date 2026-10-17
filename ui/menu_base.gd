class_name MenuBase
extends PanelContainer
## Pauses the game and centers a panel. Subclasses fill `content` in refresh().

var toggle_action: StringName = &""
var content := VBoxContainer.new()

static var open_menu: MenuBase

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(380, 0)
	add_child(content)
	Events.stats_changed.connect(func(): if visible: refresh())

func can_open() -> bool:
	return true

func refresh() -> void:
	pass

func open() -> void:
	if open_menu != null or Game.input_locked or not can_open():
		return
	open_menu = self
	_clear()
	refresh()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	if open_menu != self:
		return
	open_menu = null
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		if visible:
			close()
		else:
			open()
	elif visible and event.is_action_pressed(&"ui_cancel_menu"):
		close()

func _clear() -> void:
	for c in content.get_children():
		c.queue_free()

func title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	content.add_child(l)
