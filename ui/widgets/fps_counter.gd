class_name FpsCounter
extends Control
## Small frames-per-second readout in the top-right corner. Shown only while the
## "Show FPS" option (display/show_fps) is on; refreshed a few times a second so
## the number is readable instead of flickering every frame.

const REFRESH_TIME := 0.25
const MARGIN := 12.0
const FONT_SIZE := 22

var _label: Label
var _next_refresh := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep counting while paused
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.9))
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -160.0 - MARGIN
	_label.offset_right = -MARGIN
	_label.offset_top = MARGIN
	Settings.changed.connect(_on_setting_changed)
	_apply_visibility()

func _on_setting_changed(key: StringName) -> void:
	if key == &"display/show_fps":
		_apply_visibility()

func _apply_visibility() -> void:
	visible = Settings.get_value(&"display/show_fps")
	set_process(visible)
	_next_refresh = 0.0

func _process(delta: float) -> void:
	_next_refresh -= delta
	if _next_refresh > 0.0:
		return
	_next_refresh = REFRESH_TIME
	_label.text = "%d FPS" % int(Engine.get_frames_per_second())
