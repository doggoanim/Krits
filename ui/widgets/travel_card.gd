class_name TravelCard
extends Button
## One destination on the fast travel screen, drawn like the rest of the hand-
## made UI: a wobbly-outlined paper plate (the same button art as the menus),
## a hand-inked crystal, and black marker text. Built entirely from setup() so
## TravelMenu only has to say what each card is.
##
##   AVAILABLE  inked crystal, selectable (warm yellow when picked)
##   HERE       the checkpoint you're standing at (green, not selectable)
##   LOCKED     not discovered yet: a dashed outline and "???"

enum State { AVAILABLE, HERE, LOCKED }

const CARD_SIZE := Vector2(320, 480)
const ICON_HEIGHT := 190.0
const PLATE_MARGIN := 60.0
const CONTENT_MARGIN := 52.0   ## the plate's inked outline and rounded corners sit well inside its rect, so keep text clear of them
const TILTS := [-2.0, 1.4, -0.9, 2.0]   ## degrees; each card sits a touch crooked, like the pause menu's buttons

const PLATES: Array[Texture2D] = [
	preload("res://assets/ui/button_1.png"),
	preload("res://assets/ui/button_2.png"),
	preload("res://assets/ui/button_3.png"),
]
const TINT_IDLE := Color.WHITE
const TINT_PICKED := Color(1.0, 0.92, 0.5)
const TINT_HERE := Color(0.72, 1.0, 0.8)
const TINT_LOCKED := Color(0.8, 0.82, 0.88)

const CRYSTAL_FILL := CheckpointCrystal.UNLOCKED_COLOR   ## same blue as the checkpoint crystal itself
const HERE_FILL := Color(0.62, 1.0, 0.72)
const LOCKED_FILL := Color(0.92, 0.93, 0.96)

var spawn_id: StringName
var state := State.AVAILABLE

func setup(number: int, place: String, subtitle: String, card_state: State) -> void:
	state = card_state
	custom_minimum_size = CARD_SIZE
	disabled = state != State.AVAILABLE
	focus_mode = Control.FOCUS_ALL if state == State.AVAILABLE else Control.FOCUS_NONE
	rotation_degrees = TILTS[number % TILTS.size()]
	resized.connect(func(): pivot_offset = size * 0.5)
	_apply_styles(number)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(CONTENT_MARGIN))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	box.add_child(_label("No. %d" % number, 24, 0.45, HORIZONTAL_ALIGNMENT_LEFT))
	var icon := _Icon.new()
	icon.state = state
	icon.ink_seed = number * 7919
	icon.custom_minimum_size.y = ICON_HEIGHT
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	box.add_child(_label(place if state != State.LOCKED else "???", 40, 1.0))
	if subtitle != "" and state != State.LOCKED:
		box.add_child(_label(subtitle, 22, 0.6))
	box.add_child(_label(_status_text(), 24, 0.7 if state == State.AVAILABLE else 0.55))

func _status_text() -> String:
	match state:
		State.HERE: return "You are here"
		State.LOCKED: return "Undiscovered"
	return "Checkpoint"

func _label(text: String, size: int, alpha: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(Ink.INK, alpha))
	return l

# ------------------------------------------------------------------- styling

func _plate(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = texture
	sb.modulate_color = tint
	sb.set_texture_margin_all(PLATE_MARGIN)
	sb.set_content_margin_all(CONTENT_MARGIN)
	return sb

func _apply_styles(number: int) -> void:
	var idle := _plate(PLATES[number % PLATES.size()], TINT_IDLE)
	# Hover and focus share one look — hovering takes focus anyway (see
	# FocusPop), and a local hover style is what FocusPop shows on focus.
	var picked := _plate(PLATES[(number + 1) % PLATES.size()], TINT_PICKED)
	add_theme_stylebox_override("normal", idle)
	add_theme_stylebox_override("hover", picked)
	add_theme_stylebox_override("focus", picked)
	add_theme_stylebox_override("pressed", picked)
	add_theme_stylebox_override("hover_pressed", picked)
	add_theme_stylebox_override("disabled", _plate(PLATES[number % PLATES.size()],
			TINT_HERE if state == State.HERE else TINT_LOCKED))

## The crystal, drawn in ink: a wobbly black outline over a flat colour fill,
## a couple of facet strokes and twinkling sparkles. The line "boils" a little
## (re-wobbles a few times a second) like stop-motion; a locked one is a dashed
## outline with a question mark.
class _Icon extends Control:
	const BOIL_FPS := 6.0
	const LINE := 5.0

	var state := TravelCard.State.AVAILABLE
	var ink_seed := 1

	func _process(_delta: float) -> void:
		if state != TravelCard.State.LOCKED:
			queue_redraw()

	func _draw() -> void:
		var step := int(Time.get_ticks_msec() / 1000.0 * BOIL_FPS) if state != TravelCard.State.LOCKED else 0
		var s := ink_seed + step * 31
		var bob := sin(Time.get_ticks_msec() * 0.003) * 5.0 if state != TravelCard.State.LOCKED else 0.0
		var c := Vector2(size.x * 0.5, size.y * 0.5 + bob)
		var top := c + Vector2(0, -80)
		var right := c + Vector2(52, -6)
		var bottom := c + Vector2(0, 66)
		var left := c + Vector2(-52, -6)
		var shape := PackedVector2Array([top, right, bottom, left])
		if state == TravelCard.State.LOCKED:
			_draw_dashed(Ink.wobble(Ink.closed(shape), s, 1.4, 6))
			var font := ThemeDB.fallback_font
			draw_string(font, c + Vector2(-14, 24), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(Ink.INK, 0.4))
			return
		var fill := TravelCard.HERE_FILL if state == TravelCard.State.HERE else TravelCard.CRYSTAL_FILL
		draw_colored_polygon(shape, fill)
		draw_colored_polygon(PackedVector2Array([top, c, bottom, left]), fill.darkened(0.12))   # shaded left half
		draw_polyline(Ink.wobble(Ink.closed(shape), s, 1.6, 4), Ink.INK, LINE, true)
		draw_polyline(Ink.wobble(PackedVector2Array([top, bottom]), s + 1, 1.4, 4), Ink.INK, LINE * 0.7, true)
		draw_polyline(Ink.wobble(PackedVector2Array([left, c + Vector2(0, 8), right]), s + 2, 1.4, 3), Ink.INK, LINE * 0.6, true)
		if state == TravelCard.State.AVAILABLE:
			_draw_sparkle(c + Vector2(76, -62), 15.0, s + 3)
			_draw_sparkle(c + Vector2(-80, 30), 10.0, s + 4)

	func _draw_sparkle(at: Vector2, r: float, s: int) -> void:
		r *= 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006 + at.x)   # twinkle
		var h := Ink.wobble(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(r, 0)]), s, 0.8, 2)
		var v := Ink.wobble(PackedVector2Array([at + Vector2(0, -r), at + Vector2(0, r)]), s + 1, 0.8, 2)
		draw_polyline(h, Ink.INK, 4.0, true)
		draw_polyline(v, Ink.INK, 4.0, true)

	func _draw_dashed(line: PackedVector2Array) -> void:
		var i := 0
		while i < line.size() - 1:
			draw_line(line[i], line[i + 1], Color(Ink.INK, 0.45), 4.0, true)
			i += 2
