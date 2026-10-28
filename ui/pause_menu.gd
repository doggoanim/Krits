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

## Open/close animation: the whole screen blurs lightly (Backdrop); a darker,
## more heavily blurred side panel slides in from the left behind the list,
## and the heading + list fade in while sliding SLIDE_DISTANCE px.
## Opening Settings widens that side panel to the full screen and shows the
## Settings page centred on it (PANEL_TIME, PAGE_FADE).
const OPEN_TIME := 0.28
const CLOSE_TIME := 0.18
const SLIDE_DISTANCE := 50.0
const PORTRAIT_SLIDE := 160.0   ## px the portrait slides in from the right
const PANEL_TIME := 0.3
const PAGE_FADE := 0.15

@onready var _backdrop: ColorRect = %Backdrop
@onready var _side_panel: ColorRect = %SidePanel
@onready var _portrait: PortraitViewport = %Portrait
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
var _transitioning := false          ## a Settings open/close is mid-animation
var _backdrop_lod := 0.0             ## resting blur/tint of each layer, read from the scene
var _backdrop_tint := Color.TRANSPARENT
var _side_lod := 0.0
var _side_tint := Color.TRANSPARENT
var _portrait_left := 0.0            ## the portrait's resting offsets, read from the scene
var _portrait_right := 0.0
var _side_width := 0.0               ## the side panel's resting anchor_right (fraction of the screen)
var _heading_left := 0
var _menu_left := 0

func _ready() -> void:
	super()
	var backdrop_mat := _backdrop.material as ShaderMaterial
	_backdrop_lod = backdrop_mat.get_shader_parameter("blur_lod")
	_backdrop_tint = backdrop_mat.get_shader_parameter("tint")
	var side_mat := _side_panel.material as ShaderMaterial
	_side_lod = side_mat.get_shader_parameter("blur_lod")
	_side_tint = side_mat.get_shader_parameter("tint")
	_side_width = _side_panel.anchor_right
	_portrait_left = _portrait.offset_left
	_portrait_right = _portrait.offset_right
	_heading_left = _heading_margin.get_theme_constant("margin_left")
	_menu_left = _menu_margin.get_theme_constant("margin_left")
	for node in _items:
		node.set_meta(FocusPop.SKIP_META, true)   # the list has its own selected look (white bar)
	FocusPop.attach_all(self)   # everything else: Settings page, confirmation buttons
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
	_settings.modulate.a = 1.0
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
	if _closing or _transitioning or not event.is_action_pressed(&"ui_cancel_menu"):
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
	_set_layer(_backdrop, _backdrop_lod, _backdrop_tint, k)
	_set_layer(_side_panel, _side_lod, _side_tint, k)
	# The side panel slides in from the left edge as it opens.
	_side_panel.anchor_left = -_side_width * (1.0 - k)
	_side_panel.anchor_right = _side_width * k
	content.modulate.a = k
	_portrait.get_parent().modulate.a = k
	var shift := PORTRAIT_SLIDE * (1.0 - k)
	_portrait.offset_left = _portrait_left + shift
	_portrait.offset_right = _portrait_right + shift
	var slide := int(SLIDE_DISTANCE * (1.0 - k))
	_heading_margin.add_theme_constant_override("margin_left", _heading_left - slide)
	_menu_margin.add_theme_constant_override("margin_left", _menu_left - slide)

func _set_layer(rect: ColorRect, lod: float, tint: Color, k: float) -> void:
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("blur_lod", lod * k)
	mat.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, tint.a * k))

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

## Settings: the list fades out, the side panel widens to cover the whole
## screen, then the Settings page fades in centred on it. Closing reverses it.
func _open_settings() -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade(_portrait.get_parent(), 0.0)
	await _fade(content, 0.0)
	content.visible = false
	await _widen_panel(1.0)
	_settings.modulate.a = 0.0
	_settings.visible = true
	_settings.enter({})
	await _fade(_settings, 1.0)
	_transitioning = false

func _close_settings() -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade(_settings, 0.0)
	_settings.visible = false
	_settings.exit()
	await _widen_panel(_side_width)
	content.visible = true
	_fade(_portrait.get_parent(), 1.0)
	await _fade(content, 1.0)
	_settings_button.grab_focus()
	_transitioning = false

func _fade(node: CanvasItem, alpha: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", alpha, PAGE_FADE)
	await tw.finished

func _widen_panel(target: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_side_panel, "anchor_right", target, PANEL_TIME)
	await tw.finished

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
