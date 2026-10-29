class_name RuneBar
extends Control
## The staff's queued runes as HUD slots (replaces the old floating text over
## the player's head). Up to `slot_count` gems — fire, ice, earth — each in a
## little framed plate in its element's color, popping in as it's queued, with
## a thin timer line draining underneath until the buffer clears itself.
## Driven entirely by Events.runes_changed; the layout (position/size) lives
## in hud.tscn, the look is the exported values below.

@export var slot_count := 3
@export var slot_size := 96.0
@export var slot_gap := 10.0
@export var plate_styles: Array[StyleBox] = []   ## the hand-drawn button plates (hud.tscn assigns button_1..3), one per slot, cycled
@export var plate_margin := 24.0                 ## nine-slice margin used at slot size (the plates are wide, the slots square)
@export var empty_tint := Color(1, 1, 1, 0.3)    ## tint of an unfilled slot's plate
@export var ink := Color(0.05, 0.04, 0.06)       ## outline color of the glyphs, matching the plates' black linework

var _runes: Array = []        ## Orb.Kind values, oldest first
var _pops: Array[float] = []  ## per-slot squash-and-stretch multiplier (1.0 = rest)
var _lifetime := 1.0
var _time_left := 0.0
var _t := 0.0
var _fade := 0.0              ## 0 hidden .. 1 shown, eased in _process()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.runes_changed.connect(_on_runes_changed)
	for i in slot_count:
		_pops.append(1.0)
	modulate.a = 0.0

func _on_runes_changed(runes: Array, lifetime: float) -> void:
	var grew := runes.size() > _runes.size()
	_runes = runes.duplicate()
	_lifetime = maxf(lifetime, 0.01)
	_time_left = _lifetime
	if grew and _runes.size() <= _pops.size():
		_pop(_runes.size() - 1)
	queue_redraw()

func _pop(i: int) -> void:
	_pops[i] = 0.2
	var tw := create_tween()
	tw.tween_method(_set_pop.bind(i), 0.2, 1.0, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _set_pop(value: float, i: int) -> void:
	_pops[i] = value
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	_time_left = maxf(_time_left - delta, 0.0)
	_fade = move_toward(_fade, 1.0 if not _runes.is_empty() else 0.0, delta * 6.0)
	modulate.a = _fade
	if _fade > 0.0:
		queue_redraw()

func _draw() -> void:
	if _fade <= 0.0:
		return
	var total_w := slot_count * slot_size + (slot_count - 1) * slot_gap
	var origin := Vector2((size.x - total_w) * 0.5, 0.0)
	for i in slot_count:
		var center := origin + Vector2(i * (slot_size + slot_gap) + slot_size * 0.5, slot_size * 0.5)
		var filled := i < _runes.size()
		var pop := _pops[i] if i < _pops.size() else 1.0
		var half := slot_size * 0.5 * pop
		var rect := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
		var element: Orb.Kind = _runes[i] if filled else Orb.Kind.FIRE
		var color: Color = Orb.KIND_COLORS[element][0] if filled else empty_tint
		_draw_plate(rect, i, color)
		if filled:
			var bob := sin(_t * 3.0 + i) * 1.5
			_draw_glyph(element, center + Vector2(0, bob), half * 0.5)
	# Timer line: drains left→right-to-left until the buffer expires.
	var y := slot_size + 16.0
	var frac := clampf(_time_left / _lifetime, 0.0, 1.0)
	draw_line(Vector2(origin.x, y), Vector2(origin.x + total_w, y), Color(0, 0, 0, 0.35), 10.0, true)
	if frac > 0.0:
		var warn := Color(1, 0.35, 0.3) if frac < 0.3 else Color.WHITE
		draw_line(Vector2(origin.x + 2.0, y), Vector2(origin.x + total_w * frac - 2.0, y), ink, 10.0, true)
		draw_line(Vector2(origin.x + 4.0, y), Vector2(origin.x + total_w * frac - 4.0, y), warn, 5.0, true)

## The user's hand-drawn plate texture, nine-sliced to a square and tinted
## with the element's color (the art is white with a black outline).
func _draw_plate(rect: Rect2, slot: int, tint: Color) -> void:
	if plate_styles.is_empty():
		draw_rect(rect, tint)
		return
	var base := plate_styles[slot % plate_styles.size()]
	var style := base.duplicate() as StyleBox
	if style is StyleBoxTexture:
		var tex_style := style as StyleBoxTexture
		tex_style.texture_margin_left = plate_margin
		tex_style.texture_margin_right = plate_margin
		tex_style.texture_margin_top = plate_margin
		tex_style.texture_margin_bottom = plate_margin
		tex_style.modulate_color = tint
	draw_style_box(style, rect)

## Element glyphs — flame, snow crystal, rock — white with a black outline,
## the same inked look as the plates. `r` is the half-size.
func _draw_glyph(element: Orb.Kind, c: Vector2, r: float) -> void:
	match element:
		Orb.Kind.FIRE:
			_poly(PackedVector2Array([
				Vector2(0.05, -1.0), Vector2(0.6, -0.15), Vector2(0.55, 0.5), Vector2(0.0, 1.0),
				Vector2(-0.55, 0.5), Vector2(-0.6, -0.05), Vector2(-0.25, -0.35)]), c, r, Color.WHITE)
			_poly(PackedVector2Array([
				Vector2(0.0, -0.1), Vector2(0.32, 0.45), Vector2(0.0, 0.85), Vector2(-0.32, 0.45)]), c, r, Color(1, 0.9, 0.55))
		Orb.Kind.ICE:
			for a in 3:
				var dir := Vector2.UP.rotated(a * PI / 3.0) * r
				draw_line(c - dir, c + dir, ink, 9.0, true)
			for a in 3:
				var dir := Vector2.UP.rotated(a * PI / 3.0) * r
				draw_line(c - dir, c + dir, Color.WHITE, 4.5, true)
			draw_circle(c, r * 0.22, ink)
			draw_circle(c, r * 0.14, Color.WHITE)
		Orb.Kind.EARTH:
			_poly(PackedVector2Array([
				Vector2(-0.45, -0.85), Vector2(0.5, -0.7), Vector2(0.95, 0.0), Vector2(0.6, 0.8),
				Vector2(-0.4, 0.9), Vector2(-0.95, 0.1)]), c, r, Color.WHITE)
			_poly(PackedVector2Array([
				Vector2(-0.45, -0.85), Vector2(0.5, -0.7), Vector2(0.1, -0.1), Vector2(-0.5, 0.0)]), c, r, Color(0.85, 0.85, 0.85))

## A filled polygon with an ink outline.
func _poly(points: PackedVector2Array, c: Vector2, r: float, fill: Color) -> void:
	var pts := _xf(points, c, r)
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, ink, 3.0, true)

func _xf(points: PackedVector2Array, c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(c + p * r)
	return out
