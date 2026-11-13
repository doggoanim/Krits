class_name DiscardPrompt
extends Control
## "Discard 3 Perch?" confirmation shown over the bag. A slider picks how many
## when there's more than one. Esc / Cancel backs out; nothing is thrown away
## until Discard is pressed. Emits `confirmed(amount)` or `cancelled`, then frees itself.

signal confirmed(amount: int)
signal cancelled

const PANEL_BG := Color(1, 1, 1)
const INK := Color(0.07, 0.07, 0.1)
const DANGER := Color(0.85, 0.2, 0.2)

var _amount := 1
var _amount_label: Label

## `count`: how many the player has (the slider's maximum).
static func create(item_name: String, count: int) -> DiscardPrompt:
	var p := DiscardPrompt.new()
	p._build(item_name, maxi(count, 1))
	return p

func _build(item_name: String, count: int) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_border_width_all(6)
	style.border_color = INK
	style.set_corner_radius_all(28)
	style.set_content_margin_all(44)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 22)
	panel.add_child(box)

	box.add_child(_label("Discard %s?" % item_name, 56))
	var first_focus: Control
	if count > 1:
		_amount_label = _label("", 48)
		box.add_child(_amount_label)
		var slider := HSlider.new()
		slider.min_value = 1
		slider.max_value = count
		slider.step = 1
		slider.value = 1
		slider.custom_minimum_size = Vector2(620, 56)
		slider.value_changed.connect(func(v: float): _set_amount(int(v), count))
		box.add_child(slider)
		first_focus = slider
	_set_amount(1, count)
	box.add_child(_label("This can't be undone.", 32, 0.6))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var cancel := _button("Cancel", INK)
	cancel.pressed.connect(_cancel)
	row.add_child(cancel)
	var discard := _button("Discard", DANGER)
	discard.pressed.connect(func():
		confirmed.emit(_amount)
		queue_free())
	row.add_child(discard)
	FocusPop.attach_all(row, true)
	# Focus Cancel unless there's a slider to set first, so Enter can't throw things away by accident.
	if first_focus == null:
		first_focus = cancel
	first_focus.call_deferred(&"grab_focus")

func _set_amount(value: int, count: int) -> void:
	_amount = value
	if _amount_label != null:
		_amount_label.text = "%d of %d" % [value, count]

func _label(text: String, size: int, alpha := 1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", Color(INK, alpha))
	return l

func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 84)
	b.add_theme_font_size_override(&"font_size", 44)
	b.add_theme_color_override(&"font_color", color)
	b.add_theme_color_override(&"font_hover_color", color)
	b.add_theme_color_override(&"font_focus_color", color)
	return b

func _cancel() -> void:
	cancelled.emit()
	queue_free()

## Esc backs out of the prompt only (not the whole bag).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel_menu") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
