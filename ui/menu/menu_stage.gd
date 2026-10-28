class_name MenuStage
extends Node3D
## The 3D backdrop behind every menu screen: a pitch-black world with a star
## field and the white Krits floating dead centre. Its nodes (camera, stars,
## hero, environment) are all authored in menu_stage.tscn so they can be
## tweaked in the editor; this script only choreographs the intro.

## Seconds Krits floats alone in the middle of the screen before sliding aside.
const INTRO_HOLD := 2.0
const MOVE_TIME := 1.4
const SKIP_GRACE := 0.25   ## seconds before a key press can skip the hold

## Where Krits ends up horizontally: 0 = centre of the screen, 1 = the right
## screen edge. 0.5 would be the middle of the right half; 0.38 sits a bit
## closer to centre, still clear of the title block on the left.
@export_range(0.0, 1.0) var hero_screen_x := 0.38

var _holding := false
var _hold_start_msec := 0

@onready var _hero: MenuHero = %Hero
@onready var _camera: Camera3D = %Camera

## The splash has just faded to reveal the void: let Krits float centred for
## a beat, then slide him to the right. Awaitable.
## Pressing any key / click / button during the hold skips the rest of it
## (ignored for the first SKIP_GRACE seconds, so the press that dismissed the
## splash can't skip it by accident).
func play_intro() -> void:
	_holding = true
	_hold_start_msec = Time.get_ticks_msec()
	var elapsed := 0.0
	while _holding and elapsed < INTRO_HOLD:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_holding = false
	await move_hero_aside()

func _hold_elapsed() -> float:
	return (Time.get_ticks_msec() - _hold_start_msec) / 1000.0

func _input(event: InputEvent) -> void:
	if not _holding or _hold_elapsed() < SKIP_GRACE:
		return
	var pressed := false
	if event is InputEventKey:
		var key := event as InputEventKey
		pressed = key.pressed and not key.echo
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventJoypadButton:
		pressed = (event as InputEventJoypadButton).pressed
	if pressed:
		_holding = false
		get_viewport().set_input_as_handled()

func move_hero_aside() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_hero, "position:x", _aside_x(), MOVE_TIME)
	await tw.finished

## World-space X that lands the hero `hero_screen_x` of the way from the
## screen's centre to its right edge, worked out from the camera's own fov and
## the window's aspect so it holds at any resolution. The camera looks
## straight down -Z, so depth is just the Z gap.
func _aside_x() -> float:
	var depth := absf(_camera.global_position.z - _hero.global_position.z)
	var half_height := depth * tan(deg_to_rad(_camera.fov * 0.5))
	var view := get_viewport().get_visible_rect().size
	return half_height * (view.x / view.y) * hero_screen_x
