class_name TravelCard
extends Button
## One destination on the fast travel screen: a card with a crystal icon, the
## place's name and a status line. Built entirely from setup() so TravelMenu
## only has to say what each card is.
##
##   AVAILABLE  glowing crystal, selectable
##   HERE       the checkpoint you're standing at (not selectable)
##   LOCKED     not discovered yet: a hollow outline and "???"

enum State { AVAILABLE, HERE, LOCKED }

const CARD_SIZE := Vector2(210, 270)
const ICON_HEIGHT := 120.0
const CRYSTAL_COLOR := Color(0.35, 0.95, 1.0)
const HERE_COLOR := Color(0.55, 1.0, 0.7)
const LOCKED_COLOR := Color(0.5, 0.55, 0.68)

var spawn_id: StringName
var state := State.AVAILABLE

func setup(number: int, place: String, subtitle: String, card_state: State) -> void:
	state = card_state
	custom_minimum_size = CARD_SIZE
	disabled = state != State.AVAILABLE
	focus_mode = Control.FOCUS_ALL if state == State.AVAILABLE else Control.FOCUS_NONE
	_apply_styles()

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	box.add_child(_label("%02d" % number, 15, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_LEFT))
	var icon := _Icon.new()
	icon.state = state
	icon.custom_minimum_size.y = ICON_HEIGHT
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	var name_color := Color.WHITE if state != TravelCard.State.LOCKED else Color(1, 1, 1, 0.4)
	box.add_child(_label(place if state != TravelCard.State.LOCKED else "???", 24, name_color))
	if subtitle != "" and state != TravelCard.State.LOCKED:
		box.add_child(_label(subtitle, 15, Color(1, 1, 1, 0.55)))
	box.add_child(_label(_status_text(), 15, _status_color()))

func _status_text() -> String:
	match state:
		State.HERE: return "You are here"
		State.LOCKED: return "Undiscovered"
	return "Checkpoint"

func _status_color() -> Color:
	match state:
		State.HERE: return HERE_COLOR
		State.LOCKED: return Color(1, 1, 1, 0.3)
	return CRYSTAL_COLOR

func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

# ------------------------------------------------------------------- styling

func _box(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	return sb

func _apply_styles() -> void:
	var idle := _box(Color(0.07, 0.09, 0.15, 0.94), Color(0.3, 0.4, 0.55, 0.55), 2)
	# Hover and focus share the same look — hovering takes focus anyway (see
	# FocusPop), and a local hover style is what FocusPop shows on focus.
	var picked := _box(Color(0.1, 0.2, 0.28, 0.97), CRYSTAL_COLOR, 3)
	var here := _box(Color(0.07, 0.17, 0.14, 0.94), HERE_COLOR.darkened(0.3), 2)
	var locked := _box(Color(0.05, 0.06, 0.1, 0.8), Color(0.25, 0.3, 0.4, 0.35), 2)
	add_theme_stylebox_override("normal", idle)
	add_theme_stylebox_override("hover", picked)
	add_theme_stylebox_override("focus", picked)
	add_theme_stylebox_override("pressed", picked)
	add_theme_stylebox_override("hover_pressed", picked)
	add_theme_stylebox_override("disabled", here if state == State.HERE else locked)

## The crystal drawn on the card; floats gently and glows when it can be picked.
class _Icon extends Control:
	var state := TravelCard.State.AVAILABLE

	func _process(_delta: float) -> void:
		if state != TravelCard.State.LOCKED:
			queue_redraw()

	func _draw() -> void:
		var tint := TravelCard.LOCKED_COLOR
		if state == TravelCard.State.AVAILABLE:
			tint = TravelCard.CRYSTAL_COLOR
		elif state == TravelCard.State.HERE:
			tint = TravelCard.HERE_COLOR
		var bob := sin(Time.get_ticks_msec() * 0.003) * 4.0 if state != TravelCard.State.LOCKED else 0.0
		var c := Vector2(size.x * 0.5, size.y * 0.5 + bob)
		var top := c + Vector2(0, -50)
		var right := c + Vector2(32, -4)
		var bottom := c + Vector2(0, 40)
		var left := c + Vector2(-32, -4)
		if state == TravelCard.State.LOCKED:
			var outline := PackedVector2Array([top, right, bottom, left, top])
			draw_polyline(outline, Color(tint, 0.5), 2.0)
			return
		for i in 4:   # soft glow behind
			draw_circle(c, 30.0 + i * 12.0, Color(tint, 0.07))
		draw_colored_polygon(PackedVector2Array([top, c, bottom, left]), tint.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([top, right, bottom, c]), tint)
		draw_line(top, bottom, Color(1, 1, 1, 0.5), 1.5)
		draw_line(left, right, Color(1, 1, 1, 0.25), 1.0)
