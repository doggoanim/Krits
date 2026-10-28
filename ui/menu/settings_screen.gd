class_name SettingsScreen
extends MenuScreen
## Placeholder page so the title's Settings button has somewhere to go.
## There's nothing to configure yet — real options (volume, controls, ...)
## belong in settings_screen.tscn above the Return button, wired up here.

@onready var _return: Button = %ReturnButton

func _ready() -> void:
	_return.pressed.connect(_go_back)

func enter(_payload: Dictionary = {}) -> void:
	_return.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel_menu"):
		get_viewport().set_input_as_handled()
		_go_back()

func _go_back() -> void:
	navigate.emit(&"title", {"show_menu": true})
