extends Node
## Registers input actions in code so project.godot stays tiny.
##
## BINDINGS lists every player-rebindable action with its default key and the
## label shown on the Settings > Controls page — add a line here and it is
## registered, rebindable and listed automatically. Overrides the player chose
## are stored by the `Settings` autoload, which calls bind_key() on startup.

const BINDINGS := {
	&"move_forward": {"label": "Move Forward", "key": KEY_W},
	&"move_back": {"label": "Move Back", "key": KEY_S},
	&"move_left": {"label": "Move Left", "key": KEY_A},
	&"move_right": {"label": "Move Right", "key": KEY_D},
	&"jump": {"label": "Jump", "key": KEY_SPACE},
	&"roll_dive": {"label": "Roll / Dive", "key": KEY_SHIFT},
	&"crouch_pound": {"label": "Crouch / Pound", "key": KEY_CTRL},
	&"interact": {"label": "Interact", "key": KEY_E},
	&"menu_stats": {"label": "Stats Menu", "key": KEY_TAB},
	&"menu_travel": {"label": "Travel Menu", "key": KEY_M},
}

func _ready() -> void:
	for action in BINDINGS:
		bind_key(action, default_key(action))
	bind_key(&"ui_cancel_menu", KEY_ESCAPE)   # fixed — not rebindable

func default_key(action: StringName) -> Key:
	return BINDINGS[action]["key"]

## Makes `keycode` (a physical key) the one key for `action`, replacing
## whatever it had.
func bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
