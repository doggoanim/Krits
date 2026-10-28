class_name SplashScreen
extends MenuScreen
## The very first thing shown: an opaque black card with the studio/splash
## image fading in, held, then handed off to the title. Any key or click
## skips it. The image itself is just the `Image` TextureRect's texture in
## splash_screen.tscn — until one is assigned there, a dim placeholder label
## shows instead so the screen doesn't look broken.

const FADE_IN := 0.8
const HOLD := 2.2

@onready var _image: TextureRect = %Image
@onready var _placeholder: Label = %Placeholder

var _tween: Tween
var _done := false

func _ready() -> void:
	_placeholder.visible = _image.texture == null

func enter(_payload: Dictionary = {}) -> void:
	_done = false
	_image.modulate.a = 0.0
	_placeholder.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_image, "modulate:a", 1.0, FADE_IN)
	_tween.parallel().tween_property(_placeholder, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_callback(_finish)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _done:
		return
	var skip := false
	if event is InputEventKey:
		skip = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		skip = event.pressed
	elif event is InputEventJoypadButton:
		skip = event.pressed
	if skip:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween:
		_tween.kill()
	navigate.emit(&"title", {})
