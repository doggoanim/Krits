class_name PortraitSlot
extends Control
## Circular disc used twice around the HUD's portrait: once as a plain grey
## fallback behind the live 3D render (PortraitViewport), and once again,
## fill-less, drawn after it purely for the ring outline — see
## Hud._build_meter_cluster(), which layers fill -> viewport -> ring.

@export var draw_fill := true
@export var fill_color := Color(0.85, 0.85, 0.85)
@export var outline_color := Color(0.1, 0.1, 0.1)
@export var outline_width := 2.0

func _draw() -> void:
	var r := size.x * 0.5
	var center := size * 0.5
	if draw_fill:
		draw_circle(center, r, fill_color)
	if outline_width > 0.0:
		draw_arc(center, r - outline_width * 0.5, 0.0, TAU, 48, outline_color, outline_width, true)
