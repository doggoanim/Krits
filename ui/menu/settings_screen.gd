class_name SettingsScreen
extends MenuScreen
## Options page, split into four categories (Display / Audio / Controls /
## Accessibility) shown one at a time via the tab buttons.
##
## Every option control in settings_screen.tscn carries `metadata/setting` =
## the Settings key it edits, and this script binds them automatically by
## control type (HSlider, on/off toggle buttons, OptionButton; OptionButton item ids ARE
## the stored values). So adding an option = add a Settings key + a row in the
## scene; nothing here changes. The only generated rows are the key-binding
## buttons, because that list comes from InputSetup.BINDINGS.
##
## Each page node carries `metadata/section` (its Settings section) so
## "Reset to Defaults" resets just the category being viewed.

const SETTING_META := &"setting"
const SECTION_META := &"section"

@onready var _tab_buttons: Array[Node] = %Tabs.get_children()
@onready var _pages: Array[Node] = %Pages.get_children()
@onready var _binding_list: VBoxContainer = %BindingList
@onready var _reset: Button = %ResetButton
@onready var _return: Button = %ReturnButton

var _controls: Array[Control] = []
var _binding_buttons := {}      ## action -> Button
var _rebinding: StringName = &""   ## action waiting for a key press ("" = none)

func _ready() -> void:
	_collect_controls(self)
	for c in _controls:
		_bind(c)
	_build_binding_rows()
	for i in _tab_buttons.size():
		_tab_buttons[i].pressed.connect(_show_page.bind(i))
	_reset.pressed.connect(_on_reset)
	_return.pressed.connect(_go_back)
	_disable_tab_focus(self)

func enter(_payload: Dictionary = {}) -> void:
	_cancel_rebind()
	_sync()
	_tab_buttons[0].button_pressed = true
	_show_page(0)
	_tab_buttons[0].grab_focus()

func exit() -> void:
	_cancel_rebind()
	Settings.save()

## Tab / Shift+Tab are disabled on this page: each control's "next" and
## "previous" focus target is itself, so those keys leave focus where it is.
## Arrow keys (and Enter / Space) still move between and operate controls.
func _disable_tab_focus(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.focus_next = child.get_path()
			child.focus_previous = child.get_path()
		_disable_tab_focus(child)

# --- Input ----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Belt and braces with _disable_tab_focus(): Tab never reaches the GUI here,
	# unless we're capturing a new binding below.
	if _rebinding == &"" and is_visible_in_tree() \
			and (event.is_action_pressed(&"ui_focus_next") or event.is_action_pressed(&"ui_focus_prev")):
		get_viewport().set_input_as_handled()
		return
	if _rebinding == &"" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		_cancel_rebind()
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	Settings.set_binding(_rebinding, key)
	_cancel_rebind()
	_refresh_binding_labels()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel_menu"):
		get_viewport().set_input_as_handled()
		_go_back()

# --- Generic option controls ------------------------------------------------

func _collect_controls(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta(SETTING_META):
			_controls.append(child)
		_collect_controls(child)

func _bind(control: Control) -> void:
	var key: StringName = control.get_meta(SETTING_META)
	if control is Range:
		control.value_changed.connect(func(v: float) -> void: Settings.set_value(key, v))
	elif control is OptionButton:
		control.item_selected.connect(func(i: int) -> void:
			Settings.set_value(key, control.get_item_id(i)))
	elif control is BaseButton:
		control.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))

## Pull current values into the controls without echoing them back.
func _sync() -> void:
	for control in _controls:
		var value: Variant = Settings.get_value(control.get_meta(SETTING_META))
		if control is Range:
			control.set_value_no_signal(value)
		elif control is OptionButton:
			var idx: int = control.get_item_index(int(value))
			if idx >= 0:
				control.select(idx)
		elif control is BaseButton:
			control.set_pressed_no_signal(value)
	_refresh_binding_labels()

# --- Pages ------------------------------------------------------------------

func _show_page(index: int) -> void:
	_cancel_rebind()
	for i in _pages.size():
		_pages[i].visible = i == index

func _current_section() -> String:
	for page in _pages:
		if page.visible:
			return page.get_meta(SECTION_META)
	return ""

func _on_reset() -> void:
	var section := _current_section()
	if section != "":
		Settings.reset_defaults(section)
		_sync()

# --- Key bindings -----------------------------------------------------------

func _build_binding_rows() -> void:
	for action in InputSetup.BINDINGS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 40)
		var label := Label.new()
		label.text = InputSetup.BINDINGS[action]["label"]
		label.custom_minimum_size = Vector2(450, 0)
		label.add_theme_font_size_override("font_size", 44)
		var button := Button.new()
		button.custom_minimum_size = Vector2(380, 70)
		button.add_theme_font_size_override("font_size", 40)
		button.pressed.connect(_start_rebind.bind(action))
		row.add_child(label)
		row.add_child(button)
		_binding_list.add_child(row)
		_binding_buttons[action] = button

func _refresh_binding_labels() -> void:
	for action in _binding_buttons:
		_binding_buttons[action].text = _key_name(Settings.get_binding(action))

func _key_name(physical: Key) -> String:
	var layout_key := DisplayServer.keyboard_get_keycode_from_physical(physical)
	return OS.get_keycode_string(layout_key if layout_key != KEY_NONE else physical)

func _start_rebind(action: StringName) -> void:
	_cancel_rebind()
	_rebinding = action
	_binding_buttons[action].text = "Press a key..."

func _cancel_rebind() -> void:
	if _rebinding != &"":
		_rebinding = &""
		_refresh_binding_labels()

func _go_back() -> void:
	navigate.emit(&"title", {"show_menu": true})
