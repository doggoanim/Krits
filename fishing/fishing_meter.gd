class_name FishingMeter
extends Control
## The reel-in meter, drawn in the game's inked, hand-cut style: a cream paper
## panel with a black outline, a watery track holding the catch zone (green,
## outlined) and the darting fish (a little drawn fish that faces the way it
## swims), and a progress bar underneath that warms from red to green as the
## catch gets closer. FishingSession only feeds it numbers; all the looks live here.

const PANEL_SIZE := Vector2(540.0, 92.0)
const PAD := 16.0
const TRACK_HEIGHT := 34.0
const PROGRESS_HEIGHT := 12.0
const INK := Color(0.07, 0.07, 0.09)
const PAPER := Color(1.0, 0.975, 0.92)
const WATER := Color(0.55, 0.8, 0.92)
const WATER_DEEP := Color(0.38, 0.65, 0.82)
const ZONE := Color(0.45, 0.9, 0.5)
const ZONE_HIT := Color(0.65, 1.0, 0.55)
const FISH_BODY := Color(1.0, 0.62, 0.2)
const FISH_HALF_LENGTH := 17.0
const FISH_HALF_HEIGHT := 10.0

var zone_pos := 0.5       ## 0..1 centre of the catch zone along the track
var zone_width := 0.25    ## fraction of the track
var fish_pos := 0.5       ## 0..1
var fish_facing := 1.0    ## +1 swimming right, -1 left
var progress := 0.3       ## 0..1
var covered := false      ## is the zone on the fish right now?

var _panel := StyleBoxFlat.new()
var _t := 0.0

func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.bg_color = PAPER
	_panel.border_color = INK
	_panel.set_border_width_all(4)
	_panel.set_corner_radius_all(18)
	_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	_panel.shadow_size = 6
	_panel.shadow_offset = Vector2(0.0, 4.0)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _track_rect() -> Rect2:
	return Rect2(PAD, PAD - 2.0, PANEL_SIZE.x - PAD * 2.0, TRACK_HEIGHT)

func _progress_rect() -> Rect2:
	return Rect2(PAD, PANEL_SIZE.y - PAD - PROGRESS_HEIGHT + 2.0, PANEL_SIZE.x - PAD * 2.0, PROGRESS_HEIGHT)

func _draw() -> void:
	draw_style_box(_panel, Rect2(Vector2.ZERO, PANEL_SIZE))
	_draw_track()
	_draw_progress()

func _rounded(color: Color, radius: int, border := 0, border_color := INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.border_color = border_color
		sb.set_border_width_all(border)
	return sb

func _draw_track() -> void:
	var r := _track_rect()
	draw_style_box(_rounded(WATER, 12, 3), r)
	# A few ripples so the track reads as water.
	for i in 5:
		var x := r.position.x + r.size.x * (0.1 + 0.2 * i) + fmod(_t * 12.0, 40.0) - 20.0
		var y := r.position.y + r.size.y * (0.3 if i % 2 == 0 else 0.7)
		draw_line(Vector2(x, y), Vector2(x + 14.0, y), WATER_DEEP, 2.0)
	# The catch zone you steer.
	var zw := zone_width * r.size.x
	var zx := clampf(r.position.x + zone_pos * r.size.x - zw * 0.5, r.position.x, r.end.x - zw)
	var zone_rect := Rect2(zx, r.position.y + 3.0, zw, r.size.y - 6.0)
	draw_style_box(_rounded(ZONE_HIT if covered else ZONE, 9, 3), zone_rect)
	# The fish, drawn on top.
	var fx := r.position.x + FISH_HALF_LENGTH * 1.6 + fish_pos * (r.size.x - FISH_HALF_LENGTH * 3.2)
	_draw_fish(Vector2(fx, r.position.y + r.size.y * 0.5))

## A little cartoon fish: oval body, triangle tail, eye. `fish_facing` flips it.
func _draw_fish(center: Vector2) -> void:
	var f := fish_facing
	var wag := sin(_t * 18.0) * 3.0
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		body.append(center + Vector2(cos(a) * FISH_HALF_LENGTH * f, sin(a) * FISH_HALF_HEIGHT))
	var tail := PackedVector2Array([
		center + Vector2(-FISH_HALF_LENGTH * 0.8 * f, 0.0),
		center + Vector2(-FISH_HALF_LENGTH * 1.5 * f, -FISH_HALF_HEIGHT * 0.9 + wag),
		center + Vector2(-FISH_HALF_LENGTH * 1.5 * f, FISH_HALF_HEIGHT * 0.9 + wag),
	])
	draw_colored_polygon(tail, FISH_BODY)
	draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2], tail[0]]), INK, 3.0)
	draw_colored_polygon(body, FISH_BODY)
	draw_polyline(body + PackedVector2Array([body[0]]), INK, 3.0)
	draw_circle(center + Vector2(FISH_HALF_LENGTH * 0.45 * f, -FISH_HALF_HEIGHT * 0.25), 3.2, Color.WHITE)
	draw_circle(center + Vector2(FISH_HALF_LENGTH * 0.5 * f, -FISH_HALF_HEIGHT * 0.25), 1.6, INK)

func _draw_progress() -> void:
	var r := _progress_rect()
	draw_style_box(_rounded(Color(0.85, 0.82, 0.75), 6, 3), r)
	var frac := clampf(progress, 0.0, 1.0)
	if frac > 0.02:
		var fill := Rect2(r.position + Vector2(3.0, 3.0), Vector2((r.size.x - 6.0) * frac, r.size.y - 6.0))
		var color := Color(0.95, 0.35, 0.3).lerp(Color(0.98, 0.85, 0.3), clampf(frac * 2.0, 0.0, 1.0))
		color = color.lerp(Color(0.4, 0.85, 0.45), clampf(frac * 2.0 - 1.0, 0.0, 1.0))
		draw_style_box(_rounded(color, 3), fill)
