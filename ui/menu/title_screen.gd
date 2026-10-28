class_name TitleScreen
extends MenuScreen
## Big "Krits" on the left, with Krits himself floating on the right (see
## MenuStage). Starts on a blinking "Press any key to continue"; the first key
## or click swaps that prompt for the Play / Settings / Quit stack. Coming
## back from a deeper screen (payload "show_menu") skips the prompt.

enum Phase { PRESS_ANY_KEY, MENU }

const BLINK_TIME := 0.8

@onready var _prompt: Label = %Prompt
@onready var _buttons: VBoxContainer = %Buttons
@onready var _play: Button = %PlayButton
@onready var _settings: Button = %SettingsButton
@onready var _quit: Button = %QuitButton

var _phase := Phase.PRESS_ANY_KEY
var _blink: Tween

func _ready() -> void:
	_play.pressed.connect(func(): navigate.emit(&"slots", {}))
	_settings.pressed.connect(func(): navigate.emit(&"settings", {}))
	_quit.pressed.connect(func(): navigate.emit(&"quit", {}))

func enter(payload: Dictionary = {}) -> void:
	if payload.get("show_menu", false):
		_show_menu()
		return
	_phase = Phase.PRESS_ANY_KEY
	_buttons.visible = false
	_prompt.visible = true
	_prompt.modulate.a = 1.0
	_blink = create_tween().set_loops()
	_blink.tween_property(_prompt, "modulate:a", 0.25, BLINK_TIME)
	_blink.tween_property(_prompt, "modulate:a", 1.0, BLINK_TIME)

func exit() -> void:
	if _blink:
		_blink.kill()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _phase != Phase.PRESS_ANY_KEY:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		get_viewport().set_input_as_handled()
		_show_menu()

func _show_menu() -> void:
	_phase = Phase.MENU
	if _blink:
		_blink.kill()
	_prompt.visible = false
	_buttons.visible = true
	_buttons.modulate.a = 0.0
	create_tween().tween_property(_buttons, "modulate:a", 1.0, 0.35)
	_play.grab_focus()
