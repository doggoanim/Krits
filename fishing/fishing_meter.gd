class_name FishingMeter
extends Control
## The reel-in meter, drawn in the game's inked, hand-cut style: the same
## hand-drawn button plate as the key hints (button_with_shadow.png) as its backing, a watery track holding the catch zone (green,
## outlined) and the darting fish (a little drawn fish that faces the way it
## swims), and a progress bar underneath that warms from red to green as the
## catch gets closer. FishingSession only feeds it numbers; all the looks live here.

const PLATE_TEXTURE := preload("res://assets/ui/button_with_shadow.png")
const PLATE_REGION := Rect2(153, 168, 1633, 775)   ## same crop as KeyHintPlate: the hand-drawn button
const PANEL_SIZE := Vector2(560.0, 116.0)
const PAD_X := 38.0                                ## keeps the contents inside the button's inked edge
const PAD_TOP := 26.0
const PAD_BOTTOM := 28.0
const TRACK_HEIGHT := 34.0
const PROGRESS_HEIGHT := 12.0
const INK := Color(0.07, 0.07, 0.09)
const WATER := Color(0.3, 0.82, 0.93)         ## the water's top colour (shallow_color in world/water/water.tscn)
const RIPPLE_POINTS := 18
const RIPPLE_LENGTH := 76.0   ## px, along the track
const RIPPLE_WAVE := 5.5      ## px, how far it wiggles up and down
const WATER_DEEP := Color(0.22, 0.65, 0.78)    ## ripple lines: the same blue, a shade darker
const ZONE := Color(0.569, 0.733, 0.306)        ## grass green (albedo_color in assets/materials/grass.tres)
const ZONE_HIT := Color(0.69, 0.85, 0.4)       ## the same green, brighter while on the fish
const FISH_BODY := Color(1.0, 0.62, 0.2)
const FISH_TEXT := "FISH"
const FISH_FONT_SIZE := 24
const FISH_OUTLINE := 8
const FISH_HALF_LENGTH := 30.0   ## roughly half the word's width: keeps it inside the track at the ends

var zone_pos := 0.5       ## 0..1 centre of the catch zone along the track
var zone_width := 0.25    ## fraction of the track
var fish_pos := 0.5       ## 0..1
var progress := 0.3       ## 0..1
var covered := false      ## is the zone on the fish right now?

var _plate: AtlasTexture
var _t := 0.0

func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate = AtlasTexture.new()
	_plate.atlas = PLATE_TEXTURE
	_plate.region = PLATE_REGION

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _track_rect() -> Rect2:
	return Rect2(PAD_X, PAD_TOP, PANEL_SIZE.x - PAD_X * 2.0, TRACK_HEIGHT)

func _progress_rect() -> Rect2:
	return Rect2(PAD_X, PANEL_SIZE.y - PAD_BOTTOM - PROGRESS_HEIGHT, PANEL_SIZE.x - PAD_X * 2.0, PROGRESS_HEIGHT)

func _draw() -> void:
	draw_texture_rect(_plate, Rect2(Vector2.ZERO, PANEL_SIZE), false)   # the game's hand-drawn button, as the backing
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
		_draw_ripple(r, x, y, float(i))
	# The catch zone you steer.
	var zw := zone_width * r.size.x
	var zx := clampf(r.position.x + zone_pos * r.size.x - zw * 0.5, r.position.x, r.end.x - zw)
	var zone_rect := Rect2(zx, r.position.y + 3.0, zw, r.size.y - 6.0)
	draw_style_box(_rounded(ZONE_HIT if covered else ZONE, 9, 3), zone_rect)
	# The fish, drawn on top.
	var fx := r.position.x + FISH_HALF_LENGTH + 4.0 + fish_pos * (r.size.x - (FISH_HALF_LENGTH + 4.0) * 2.0)
	_draw_fish(Vector2(fx, r.position.y + r.size.y * 0.5))

## One short wavy ripple line that drifts along the track and ripples as it goes,
## each with its own phase, kept inside the track.
func _draw_ripple(track: Rect2, x: float, y: float, phase: float) -> void:
	var points := PackedVector2Array()
	for k in RIPPLE_POINTS:
		var px := x + float(k) * RIPPLE_LENGTH / float(RIPPLE_POINTS - 1)
		if px < track.position.x + 6.0 or px > track.end.x - 6.0:
			continue
		var taper := sin(PI * float(k) / float(RIPPLE_POINTS - 1))   # ends stay on the line's own height
		points.append(Vector2(px, y + sin(_t * 6.0 + phase * 1.7 + float(k) * 0.75) * RIPPLE_WAVE * taper))
	if points.size() >= 2:
		draw_polyline(points, WATER_DEEP, 3.0, true)

## The fish is just the word "FISH", bobbing a little, in the game's font with an ink outline.
func _draw_fish(center: Vector2) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(FISH_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FISH_FONT_SIZE)
	var bob := sin(_t * 9.0) * 1.5
	var pos := Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.3 + bob)
	draw_string_outline(font, pos, FISH_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FISH_FONT_SIZE, FISH_OUTLINE, INK)
	draw_string(font, pos, FISH_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FISH_FONT_SIZE, FISH_BODY)

func _draw_progress() -> void:
	var r := _progress_rect()
	draw_style_box(_rounded(Color(0.85, 0.82, 0.75), 6, 3), r)
	var frac := clampf(progress, 0.0, 1.0)
	if frac > 0.02:
		var fill := Rect2(r.position + Vector2(3.0, 3.0), Vector2((r.size.x - 6.0) * frac, r.size.y - 6.0))
		var color := Color(0.95, 0.35, 0.3).lerp(Color(0.98, 0.85, 0.3), clampf(frac * 2.0, 0.0, 1.0))
		color = color.lerp(ZONE, clampf(frac * 2.0 - 1.0, 0.0, 1.0))
		draw_style_box(_rounded(color, 3), fill)
