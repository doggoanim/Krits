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
	&"dialogue_auto": {"label": "Auto-Advance Dialogue", "key": KEY_R},
	&"menu_stats": {"label": "Stats Menu", "key": KEY_TAB},
	&"menu_travel": {"label": "Travel Menu", "key": KEY_M},
}

## The movement actions also steer UI focus: whatever key an action is bound
## to is added to the matching built-in ui_* action (alongside its arrow key /
## gamepad), so W/A/S/D (or the player's rebinds) move between menu controls
## and adjust sliders just like the arrow keys. Kept in step by bind_key().
const UI_MIRRORS := {
	&"move_forward": &"ui_up",
	&"move_back": &"ui_down",
	&"move_left": &"ui_left",
	&"move_right": &"ui_right",
}

var _mirrored: Dictionary = {}   ## ui action -> the InputEventKey we added to it

func _ready() -> void:
	for action in BINDINGS:
		bind_key(action, default_key(action))
	bind_key(&"ui_cancel_menu", KEY_ESCAPE)   # fixed — not rebindable

## Human-readable name of a physical key, in the player's own keyboard layout
## ("E", "Shift", "Space"...) — for on-screen prompts and the rebind list.
func key_label(physical: Key) -> String:
	var layout_key := DisplayServer.keyboard_get_keycode_from_physical(physical)
	return OS.get_keycode_string(layout_key if layout_key != KEY_NONE else physical)

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
	_mirror_to_ui(action, keycode)

func _mirror_to_ui(action: StringName, keycode: Key) -> void:
	if not UI_MIRRORS.has(action):
		return
	var ui_action: StringName = UI_MIRRORS[action]
	if not InputMap.has_action(ui_action):
		return
	if _mirrored.has(ui_action):
		InputMap.action_erase_event(ui_action, _mirrored[ui_action])
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(ui_action, ev)
	_mirrored[ui_action] = ev
