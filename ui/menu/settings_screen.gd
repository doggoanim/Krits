class_name SettingsScreen
extends MenuScreen
## Options page: master / music / SFX volume sliders and a fullscreen toggle.
## All values live in the `Settings` autoload (core/settings.gd), which applies
## them immediately and persists them; this screen only reflects and edits
## them. To add an option, add a row in settings_screen.tscn and wire it in
## _ready()/_sync().

@onready var _master: HSlider = %MasterSlider
@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _fullscreen: CheckButton = %FullscreenCheck
@onready var _return: Button = %ReturnButton

func _ready() -> void:
	_bind_slider(_master, &"Master")
	_bind_slider(_music, &"Music")
	_bind_slider(_sfx, &"SFX")
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_return.pressed.connect(_go_back)

func enter(_payload: Dictionary = {}) -> void:
	_sync()
	_master.grab_focus()

func exit() -> void:
	Settings.save()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel_menu"):
		get_viewport().set_input_as_handled()
		_go_back()

func _bind_slider(slider: HSlider, bus: StringName) -> void:
	slider.value_changed.connect(func(v: float) -> void: Settings.set_volume(bus, v))
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.save())

## Pull the current values into the controls without echoing them back.
func _sync() -> void:
	_master.set_value_no_signal(Settings.get_volume(&"Master"))
	_music.set_value_no_signal(Settings.get_volume(&"Music"))
	_sfx.set_value_no_signal(Settings.get_volume(&"SFX"))
	_fullscreen.set_pressed_no_signal(Settings.is_fullscreen())

func _on_fullscreen_toggled(on: bool) -> void:
	Settings.set_fullscreen(on)
	Settings.save()

func _go_back() -> void:
	navigate.emit(&"title", {"show_menu": true})
