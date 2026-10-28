class_name MenuBase
extends PanelContainer
## Pauses the game and centers a panel. Subclasses fill `content` in refresh().
## The panel chrome (centered PanelContainer + its Content VBoxContainer)
## lives in menu_base.tscn — StatsMenu/TravelMenu inherit that scene and just
## swap in their own script, so editing menu_base.tscn's layout/size/position
## updates every menu built on it at once.

@onready var content: VBoxContainer = %Content

var toggle_action: StringName = &""

static var open_menu: MenuBase
## Frame a menu last closed on — lets PauseMenu tell "this same Esc press just
## closed another menu" apart from a fresh Esc press (see PauseMenu).
static var last_close_frame := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.stats_changed.connect(func(): if visible: refresh())

func can_open() -> bool:
	return true

func refresh() -> void:
	pass

func open() -> void:
	if open_menu != null or Game.input_locked or not can_open():
		return
	if DialogueBox.instance != null and DialogueBox.instance.is_active():
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
	last_close_frame = Engine.get_process_frames()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# toggle_action is left empty by a menu that's only ever opened
	# programmatically (ShopMenu, opened by a ShopKeeper in the world) rather
	# than via its own hotkey — is_action_pressed("") would just be an
	# invalid-action error, so skip the check entirely rather than call it.
	if toggle_action != &"" and event.is_action_pressed(toggle_action):
		if visible:
			close()
		else:
			open()
	elif visible and event.is_action_pressed(&"ui_cancel_menu"):
		close()

func _clear() -> void:
	for c in content.get_children():
		c.queue_free()

## Dynamic content (row(s) added per the current game state in refresh()) —
## left as code since there's a variable number of them, not fixed layout.
func title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	content.add_child(l)
