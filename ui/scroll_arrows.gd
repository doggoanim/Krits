class_name ScrollArrows
extends Control
## The wordless "you can scroll between these" cue for InteractPrompt: an up
## chevron above the key plate and a down chevron below it, drawn as shapes
## (no font needed). Origin is the prompt's centre; InteractPrompt moves it
## each frame and sets `half_height` to the plate's drawn half-height.
## pulse() nudges the matching arrow when the player actually scrolls.

const ARROW_W := 26.0
const ARROW_H := 14.0
const GAP := 8.0
const PULSE_PX := 7.0
const PULSE_DECAY := 6.0

var half_height := 26.0
var _pulse_up := 0.0
var _pulse_down := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## step < 0 = scrolled up, > 0 = scrolled down.
func pulse(step: int) -> void:
	if step < 0:
		_pulse_up = 1.0
	else:
		_pulse_down = 1.0

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_up = move_toward(_pulse_up, 0.0, delta * PULSE_DECAY)
	_pulse_down = move_toward(_pulse_down, 0.0, delta * PULSE_DECAY)
	queue_redraw()

func _draw() -> void:
	var top := -(half_height + GAP) - _pulse_up * PULSE_PX
	_chevron(Vector2(0.0, top), -1.0, _pulse_up)
	var bottom := (half_height + GAP) + _pulse_down * PULSE_PX
	_chevron(Vector2(0.0, bottom), 1.0, _pulse_down)

## A filled triangle with a dark outline; `dir` -1 points up, +1 points down.
func _chevron(tip_base: Vector2, dir: float, pulse_amount: float) -> void:
	var w := ARROW_W * (1.0 + 0.25 * pulse_amount)
	var h := ARROW_H * (1.0 + 0.25 * pulse_amount)
	var tip := tip_base + Vector2(0.0, dir * h)   # away from the plate
	var pts := PackedVector2Array([tip_base + Vector2(-w * 0.5, 0.0),
			tip_base + Vector2(w * 0.5, 0.0), tip])
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polyline(outline, Color.BLACK, 3.0, true)
