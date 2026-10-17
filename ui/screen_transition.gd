class_name ScreenTransition
extends CanvasLayer
## Dissolve overlay. `await dissolve_in()` covers the screen, `await dissolve_out()` reveals it.

var _rect := ColorRect.new()
var _mat := ShaderMaterial.new()
var _progress := 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat.shader = load("res://ui/dissolve.gdshader")
	_rect.material = _mat
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_set_progress(0.0)

func dissolve_in(duration := 0.9) -> void:
	await _tween_to(1.0, duration)

func dissolve_out(duration := 0.9) -> void:
	await _tween_to(0.0, duration)

func _tween_to(target: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_progress, _progress, target, duration)
	await tw.finished

func _set_progress(v: float) -> void:
	_progress = v
	_mat.set_shader_parameter("progress", v)
