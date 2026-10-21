extends Node
## Registers input actions in code so project.godot stays tiny.

func _ready() -> void:
	_key(&"move_forward", KEY_W)
	_key(&"move_back", KEY_S)
	_key(&"move_left", KEY_A)
	_key(&"move_right", KEY_D)
	_key(&"jump", KEY_SPACE)
	_key(&"roll_dive", KEY_SHIFT)
	_key(&"crouch_pound", KEY_CTRL)
	_key(&"interact", KEY_E)
	_key(&"menu_stats", KEY_TAB)
	_key(&"menu_travel", KEY_M)
	_key(&"ui_cancel_menu", KEY_ESCAPE)

func _key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
