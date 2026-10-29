class_name RuneBar
extends Control
## The staff's queued runes as HUD slots (replaces the old floating text over
## the player's head). Up to `slot_count` gems — fire, ice, earth — each in a
## little framed plate in its element's color, popping in as it's queued, with
## a thin timer line draining underneath until the buffer clears itself.
## Driven entirely by Events.runes_changed; the layout (position/size) lives
## in hud.tscn, the look is the exported values below.

@export var slot_count := 3
@export var slot_size := 76.0
@export var slot_gap := 16.0
@export var plate_color := Color(0.07, 0.06, 0.1, 0.88)
@export var empty_color := Color(1, 1, 1, 0.14)
@export var corner_radius := 18

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
		var color: Color = Orb.KIND_COLORS[element][0] if filled else empty_color
		_draw_plate(rect, color, filled)
		if filled:
			var bob := sin(_t * 3.0 + i) * 1.5
			_draw_glyph(element, center + Vector2(0, bob), half * 0.52, color)
	# Timer line: drains left→right-to-left until the buffer expires.
	var y := slot_size + 12.0
	var frac := clampf(_time_left / _lifetime, 0.0, 1.0)
	draw_line(Vector2(origin.x, y), Vector2(origin.x + total_w, y), Color(0, 0, 0, 0.45), 6.0, true)
	if frac > 0.0:
		var warn := Color(1, 0.35, 0.3) if frac < 0.3 else Color(1, 1, 1, 0.9)
		draw_line(Vector2(origin.x, y), Vector2(origin.x + total_w * frac, y), warn, 4.0, true)

func _draw_plate(rect: Rect2, color: Color, filled: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(corner_radius)
	sb.bg_color = plate_color
	sb.set_border_width_all(4 if filled else 2)
	sb.border_color = color
	if filled:
		sb.shadow_color = Color(color, 0.55)
		sb.shadow_size = 10
	draw_style_box(sb, rect)
	if filled:   # soft inner tint so the plate glows in the element's color
		var inner := StyleBoxFlat.new()
		inner.set_corner_radius_all(maxi(corner_radius - 5, 2))
		inner.bg_color = Color(color, 0.22)
		draw_style_box(inner, rect.grow(-5.0))

## Hand-drawn element glyphs: flame, snow crystal, rock. `r` is the half-size.
func _draw_glyph(element: Orb.Kind, c: Vector2, r: float, color: Color) -> void:
	var light := color.lerp(Color.WHITE, 0.55)
	match element:
		Orb.Kind.FIRE:
			var flame := PackedVector2Array([
				Vector2(0.05, -1.0), Vector2(0.6, -0.15), Vector2(0.55, 0.5), Vector2(0.0, 1.0),
				Vector2(-0.55, 0.5), Vector2(-0.6, -0.05), Vector2(-0.25, -0.35)])
			draw_colored_polygon(_xf(flame, c, r), color.lerp(Color.WHITE, 0.15))
			var core := PackedVector2Array([
				Vector2(0.0, -0.1), Vector2(0.32, 0.45), Vector2(0.0, 0.85), Vector2(-0.32, 0.45)])
			draw_colored_polygon(_xf(core, c, r), light)
		Orb.Kind.ICE:
			for a in 3:
				var dir := Vector2.UP.rotated(a * PI / 3.0) * r
				draw_line(c - dir, c + dir, light, 4.0, true)
				# little barbs near each tip
				for sgn: float in [-1.0, 1.0]:
					var tip: Vector2 = dir * sgn
					var barb := tip * 0.62
					var side := tip.orthogonal().normalized() * r * 0.24
					draw_line(c + barb, c + barb + side - tip * 0.18, light, 3.0, true)
					draw_line(c + barb, c + barb - side - tip * 0.18, light, 3.0, true)
			draw_circle(c, r * 0.18, Color.WHITE)
		Orb.Kind.EARTH:
			var rock := PackedVector2Array([
				Vector2(-0.45, -0.85), Vector2(0.5, -0.7), Vector2(0.95, 0.0), Vector2(0.6, 0.8),
				Vector2(-0.4, 0.9), Vector2(-0.95, 0.1)])
			draw_colored_polygon(_xf(rock, c, r), color.lerp(Color.WHITE, 0.1))
			var facet := PackedVector2Array([
				Vector2(-0.45, -0.85), Vector2(0.5, -0.7), Vector2(0.1, -0.1), Vector2(-0.5, 0.0)])
			draw_colored_polygon(_xf(facet, c, r), light)
			draw_polyline(_xf(PackedVector2Array([Vector2(0.1, -0.1), Vector2(0.35, 0.55)]), c, r), light, 3.0, true)

func _xf(points: PackedVector2Array, c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(c + p * r)
	return out
