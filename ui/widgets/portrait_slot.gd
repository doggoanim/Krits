class_name PortraitSlot
extends Control
## Placeholder circular portrait at the left end of the HP/Stamina cluster.
## Drawn as a plain grey disc for now; swap in real art later by adding a
## TextureRect child sized to `size` (CenterContainer + a circular viewport
## mask, say), or by extending _draw() to blit a portrait texture instead of
## the flat color.

@export var fill_color := Color(0.85, 0.85, 0.85)
@export var outline_color := Color(0.1, 0.1, 0.1)
@export var outline_width := 2.0

func _draw() -> void:
	var r := size.x * 0.5
	var center := size * 0.5
	draw_circle(center, r, fill_color)
	if outline_width > 0.0:
		draw_arc(center, r - outline_width * 0.5, 0.0, TAU, 48, outline_color, outline_width, true)
