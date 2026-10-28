extends Node
## Autoload `ShaderClock`: keeps shader animation from running while the game
## is paused. Shaders read the built-in TIME, which never stops; this node adds
## up every second spent paused and publishes it as the global shader
## parameter `time_offset`, and the wind, water and low-HP-vignette shaders use
## `TIME - time_offset` — so while paused that value stays put and everything
## animated by it freezes, then carries on from where it left off.
##
## Left unset (the editor's own 3D viewport never runs this) the offset is 0 and
## the shaders just behave like plain TIME.
##
## To make a new shader pause-aware: add `global uniform float time_offset;`
## and use `(TIME - time_offset)` wherever you'd use TIME.

const PARAM := &"time_offset"

var _paused_total := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # must keep counting while paused
	RenderingServer.global_shader_parameter_set(PARAM, 0.0)

func _process(delta: float) -> void:
	if not get_tree().paused:
		return
	_paused_total += delta
	RenderingServer.global_shader_parameter_set(PARAM, _paused_total)
