class_name Spinner
extends Control
## A small spinning arc — the "something is happening" mark. Purely visual:
## it spins while visible and draws an open ring with a bright leading arc.

@export var color := Color(1.0, 0.9, 0.55)
@export var thickness := 3.0
@export var speed := 6.0   ## radians per second

func _process(delta: float) -> void:
	rotation += speed * delta   # rotates around pivot_offset (set to the centre in the scene)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - thickness
	draw_arc(c, r, 0.0, TAU, 32, Color(color, 0.25), thickness, true)
	draw_arc(c, r, 0.0, PI * 0.75, 20, color, thickness, true)
