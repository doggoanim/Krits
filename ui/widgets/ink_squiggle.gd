class_name InkSquiggle
extends Control
## A hand-drawn wavy underline: a thick ink stroke with a thinner white one on
## top, like the sticker-style headings. Size it with custom_minimum_size.

@export var waves := 9
@export var amplitude := 5.0
@export var ink_width := 12.0
@export var fill_width := 6.0
@export var fill_color := Color.WHITE

func _draw() -> void:
	var margin := ink_width
	var line := Ink.squiggle(Vector2(margin, size.y * 0.5), Vector2(size.x - margin, size.y * 0.5),
			waves, amplitude)
	draw_polyline(line, Ink.INK, ink_width, true)
	draw_polyline(line, fill_color, fill_width, true)
