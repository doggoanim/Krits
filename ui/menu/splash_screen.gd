class_name SplashScreen
extends MenuScreen
## The very first thing shown: an opaque black card with the studio/splash
## image fading in, held, then handed off to the title. Any key or click
## skips it. `frames` (set in splash_screen.tscn) are redrawn versions of the
## same card; a random one is swapped in every FRAME_TIME seconds so the
## hand-drawn lines "boil" like a looping animation. With no frames assigned,
## a dim placeholder label shows instead so the screen doesn't look broken.

const FADE_IN := 0.8
const HOLD := 2.2
const FRAME_TIME := 0.12   ## ~7 frames at 60fps between each swap

@export var frames: Array[Texture2D] = []

@onready var _image: TextureRect = %Image
@onready var _placeholder: Label = %Placeholder

var _tween: Tween
var _done := false
var _frame_t := 0.0
var _frame_idx := -1

func _ready() -> void:
	_placeholder.visible = frames.is_empty() and _image.texture == null
	if not frames.is_empty():
		_pick_frame()

func _process(delta: float) -> void:
	if _done or frames.size() < 2 or not is_visible_in_tree():
		return
	_frame_t -= delta
	if _frame_t <= 0.0:
		_frame_t = FRAME_TIME
		_pick_frame()

## A random frame, never the same one twice running (that would read as a
## stall rather than a flicker).
func _pick_frame() -> void:
	var i := randi() % frames.size()
	while frames.size() > 1 and i == _frame_idx:
		i = randi() % frames.size()
	_frame_idx = i
	_image.texture = frames[i]

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
