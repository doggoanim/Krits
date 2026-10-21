class_name ScreenTransition
extends CanvasLayer
## Dissolve overlay. `await dissolve_in()` covers the screen, `await dissolve_out()` reveals it.
## The full-rect Rect + its dissolve shader material live in screen_transition.tscn.

@onready var _rect: ColorRect = %Rect
@onready var _mat: ShaderMaterial = _rect.material

var _progress := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
