class_name MenuStage
extends Node3D
## The 3D backdrop behind every menu screen: a pitch-black world with a star
## field and the white Krits floating dead centre. Its nodes (camera, stars,
## hero, environment) are all authored in menu_stage.tscn so they can be
## tweaked in the editor; this script only choreographs the intro.

## Seconds Krits floats alone in the middle of the screen before sliding aside.
const INTRO_HOLD := 2.0
const MOVE_TIME := 1.4

## Where Krits ends up horizontally: 0 = centre of the screen, 1 = the right
## screen edge. 0.5 puts him in the middle of the right half, clear of the
## title block on the left.
@export_range(0.0, 1.0) var hero_screen_x := 0.5

@onready var _hero: MenuHero = %Hero
@onready var _camera: Camera3D = %Camera

## The splash has just faded to reveal the void: let Krits float centred for
## a beat, then slide him to the right. Awaitable.
func play_intro() -> void:
	await get_tree().create_timer(INTRO_HOLD).timeout
	await move_hero_aside()

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
