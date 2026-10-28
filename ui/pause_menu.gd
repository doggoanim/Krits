class_name PauseMenu
extends MenuBase
## Esc in the world: freezes the game (MenuBase pauses the tree and frees the
## mouse) and shows Resume / Settings / Main Menu / Quit. Built on
## MenuBase so it shares the "only one menu open at a time" rule with the stats
## / travel / shop menus, but its layout is a full-screen overlay defined in
## pause_menu.tscn, not MenuBase's small centred panel.
##
## Three layers, one visible at a time: the button page (`Content`), the
## Settings page (the same SettingsScreen the title menu uses), and a
## Yes/Cancel confirmation for the two actions that throw away progress since
## the last checkpoint (the game only saves at fast-travel points — see
## Spawnpoint.activate(); there is deliberately no manual save).
## Esc always steps back one layer, and closes the menu from the top.

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"

## Font size of the highlighted entry, and the fraction of it each entry gets by
## its distance from the selection (0 steps away, 1, 2, ...; the last value
## repeats) — the list fans out from the selection like Super Mario Odyssey's.
const SELECTED_FONT := 88
const FONT_SCALES: Array[float] = [1.0, 0.78, 0.52, 0.44]

## Open/close animation: the backdrop blurs/darkens in, the heading and list
## fade in while sliding SLIDE_DISTANCE px in from the left.
const OPEN_TIME := 0.28
const CLOSE_TIME := 0.18
const SLIDE_DISTANCE := 50.0

@onready var _backdrop: ColorRect = %Backdrop
@onready var _heading_margin: MarginContainer = %HeadingMargin
@onready var _menu_margin: MarginContainer = %MenuMargin
@onready var _items: Array[Node] = %Items.get_children()
@onready var _resume: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _main_menu: Button = %MainMenuButton
@onready var _quit: Button = %QuitButton
@onready var _settings: SettingsScreen = %Settings
@onready var _confirm: Control = %Confirm
@onready var _confirm_message: Label = %ConfirmMessage
@onready var _confirm_yes: Button = %ConfirmYes
@onready var _confirm_no: Button = %ConfirmNo

var _on_confirmed := Callable()
var _anim: Tween
var _closing := false
var _blur_lod := 0.0                 ## resting backdrop values, read from the scene
var _tint := Color.TRANSPARENT
var _heading_left := 0
var _menu_left := 0

func _ready() -> void:
	super()
	var mat := _backdrop.material as ShaderMaterial
	_blur_lod = mat.get_shader_parameter("blur_lod")
	_tint = mat.get_shader_parameter("tint")
	_heading_left = _heading_margin.get_theme_constant("margin_left")
	_menu_left = _menu_margin.get_theme_constant("margin_left")
	for node in _items:
		var item := node as Button
		item.focus_entered.connect(_update_item_sizes)
		item.mouse_entered.connect(item.grab_focus)   # hovering selects, like the keyboard does
	_resume.pressed.connect(close)
	_settings_button.pressed.connect(_open_settings)
	_main_menu.pressed.connect(_ask.bind("Return to the main menu?\nProgress since your last\ncheckpoint is lost.", _go_main_menu))
	_quit.pressed.connect(_ask.bind("Quit the game?\nProgress since your last\ncheckpoint is lost.", get_tree().quit))
	_confirm_yes.pressed.connect(_accept)
	_confirm_no.pressed.connect(_close_confirm)
	_settings.navigate.connect(func(_target: StringName, _payload: Dictionary) -> void: _close_settings())

func open() -> void:
	# Don't reopen on the very Esc press that just closed another menu.
	if Engine.get_process_frames() == last_close_frame:
		return
	super()
	if open_menu != self:
		return
	_settings.visible = false
	_confirm.visible = false
	content.visible = true
	_resume.grab_focus()
	_set_progress(0.0)
	_play(true)

## Plays the close animation, then actually closes (and unpauses).
func close() -> void:
	if open_menu != self or _closing:
		return
	_closing = true
	await _play(false)
	_closing = false
	close_immediately()

# MenuBase's open() calls these; the pause menu's content is fixed in the scene.
func _clear() -> void:
	pass

func refresh() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if _closing or not event.is_action_pressed(&"ui_cancel_menu"):
		return
	if not visible:
		open()
	elif _confirm.visible:
		_close_confirm()
	elif _settings.visible:
		return   # SettingsScreen handles its own Esc (-> navigate -> _close_settings)
	else:
		close()
	get_viewport().set_input_as_handled()

# --- Open / close animation ---------------------------------------------------

func _play(opening: bool) -> void:
	if _anim and _anim.is_valid():
		_anim.kill()
	_anim = create_tween()   # runs while paused: this node's process mode is ALWAYS
	_anim.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	_anim.tween_method(_set_progress, 0.0 if opening else 1.0, 1.0 if opening else 0.0,
			OPEN_TIME if opening else CLOSE_TIME)
	await _anim.finished

## 0 = fully clear (as if the menu weren't there), 1 = fully shown.
func _set_progress(k: float) -> void:
	var mat := _backdrop.material as ShaderMaterial
	mat.set_shader_parameter("blur_lod", _blur_lod * k)
	mat.set_shader_parameter("tint", Color(_tint.r, _tint.g, _tint.b, _tint.a * k))
	content.modulate.a = k
	var slide := int(SLIDE_DISTANCE * (1.0 - k))
	_heading_margin.add_theme_constant_override("margin_left", _heading_left - slide)
	_menu_margin.add_theme_constant_override("margin_left", _menu_left - slide)

## Sizes every entry by its distance from the focused one.
func _update_item_sizes() -> void:
	var selected := -1
	for i in _items.size():
		if (_items[i] as Button).has_focus():
			selected = i
	if selected < 0:
		return
	for i in _items.size():
		var fraction := FONT_SCALES[mini(abs(i - selected), FONT_SCALES.size() - 1)]
		var font_size := int(SELECTED_FONT * fraction)
		(_items[i] as Button).add_theme_font_size_override("font_size", font_size)

# --- Settings page ------------------------------------------------------------

func _open_settings() -> void:
	content.visible = false
	_settings.visible = true
	_settings.enter({})

func _close_settings() -> void:
	_settings.visible = false
	_settings.exit()
	content.visible = true
	_settings_button.grab_focus()

# --- Confirmation -------------------------------------------------------------

func _ask(message: String, action: Callable) -> void:
	_on_confirmed = action
	_confirm_message.text = message
	_confirm.visible = true
	_confirm_no.grab_focus()   # default to the safe choice

func _close_confirm() -> void:
	_confirm.visible = false
	_on_confirmed = Callable()
	_main_menu.grab_focus()

func _accept() -> void:
	var action := _on_confirmed
	_confirm.visible = false
	_on_confirmed = Callable()
	action.call()

func _go_main_menu() -> void:
	close_immediately()   # unpauses and clears open_menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MainMenu.return_to_title = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
