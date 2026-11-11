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
const BOIL_RATE := 10.0       ## how many times per second the hand-drawn wobble "redraws"
const BOX_WOBBLE := 3.4       ## px, how far the frame/box corners wander
const PLATE_JITTER := 3.2     ## px, how far the backing plate shifts between redraws
const PLATE_TURN := 0.018     ## rad, how far it rocks
const CORNER_STEPS := 5
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
	# The backing shifts and rocks a hair every few frames (the same redrawn-by-hand
	# "boil" as the arena's chalk), and every box below wobbles with it.
	var step := floorf(_t * BOIL_RATE)
	draw_set_transform_matrix(Transform2D(_hash(step, 91.0) * PLATE_TURN, PANEL_SIZE * 0.5 - Vector2(PANEL_SIZE * 0.5).rotated(_hash(step, 91.0) * PLATE_TURN) + Vector2(_hash(step, 7.0), _hash(step, 13.0)) * PLATE_JITTER))
	draw_texture_rect(_plate, Rect2(Vector2.ZERO, PANEL_SIZE), false)   # the game's hand-drawn button, as the backing
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_track()
	_draw_progress()

## Deterministic -1..1 noise from a step number and a salt: a different value
## every redraw "step", but the same one for the whole step.
static func _hash(step: float, salt: float) -> float:
	return sin(step * 12.9898 + salt * 78.233) * 0.5 + sin(step * 4.1414 + salt * 11.135) * 0.5

## A rounded box whose corners wander a little each redraw step, filled and
## inked. Replaces draw_style_box so the frame has the hand-drawn wobble.
func _wobbly_box(rect: Rect2, fill: Color, radius: float, border := 0.0, salt := 0.0) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	# A box narrower than two corner radii (a nearly empty progress bar) would
	# make the corners overlap into a polygon that can't be triangulated; shrink
	# the corners, and the wobble with them, to fit.
	var small := minf(rect.size.x, rect.size.y)
	radius = minf(radius, small * 0.5)
	var wobble := BOX_WOBBLE * minf(1.0, small / 14.0)
	var step := floorf(_t * BOIL_RATE)
	var pts := PackedVector2Array()
	var centers := [
		rect.position + Vector2(radius, radius),
		Vector2(rect.end.x - radius, rect.position.y + radius),
		rect.end - Vector2(radius, radius),
		Vector2(rect.position.x + radius, rect.end.y - radius)]
	var n := 0
	for c in 4:
		for k in CORNER_STEPS + 1:
			var ang := PI + (c + float(k) / CORNER_STEPS) * PI * 0.5
			var wob := Vector2(_hash(step, salt + n * 1.3), _hash(step, salt + n * 1.3 + 50.0)) * wobble
			pts.append(centers[c] + Vector2(cos(ang), sin(ang)) * radius + wob)
			n += 1
	if Geometry2D.triangulate_polygon(pts).is_empty():
		draw_rect(rect, fill)   # the wobble tangled it up: fall back to a plain box this frame
		if border > 0.0:
			draw_rect(rect, INK, false, border)
		return
	draw_colored_polygon(pts, fill)
	if border > 0.0:
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, INK, border, true)

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
	_wobbly_box(r, WATER, 12.0, 3.0, 1.0)
	# A few ripples so the track reads as water.
	for i in 5:
		var x := r.position.x + r.size.x * (0.1 + 0.2 * i) + fmod(_t * 12.0, 40.0) - 20.0
		var y := r.position.y + r.size.y * (0.3 if i % 2 == 0 else 0.7)
		_draw_ripple(r, x, y, float(i))
	# The catch zone you steer.
	var zw := zone_width * r.size.x
	var zx := clampf(r.position.x + zone_pos * r.size.x - zw * 0.5, r.position.x, r.end.x - zw)
	var zone_rect := Rect2(zx, r.position.y + 3.0, zw, r.size.y - 6.0)
	_wobbly_box(zone_rect, ZONE_HIT if covered else ZONE, 9.0, 3.0, 2.0)
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
	_wobbly_box(r, Color(0.85, 0.82, 0.75), 6.0, 3.0, 3.0)
	var frac := clampf(progress, 0.0, 1.0)
	if frac > 0.02:
		var fill := Rect2(r.position + Vector2(3.0, 3.0), Vector2((r.size.x - 6.0) * frac, r.size.y - 6.0))
		var color := Color(0.95, 0.35, 0.3).lerp(Color(0.98, 0.85, 0.3), clampf(frac * 2.0, 0.0, 1.0))
		color = color.lerp(ZONE, clampf(frac * 2.0 - 1.0, 0.0, 1.0))
		_wobbly_box(fill, color, 3.0, 0.0, 4.0)
