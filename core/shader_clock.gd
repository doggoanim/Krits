extends Node
## Autoload `ShaderClock`: feeds the global shader parameter `game_time`,
## which the wind, water and low-HP-vignette shaders use instead of TIME.
## TIME is a wall clock that keeps ticking while the tree is paused; this node
## is pausable (default process mode), so it stops accumulating when the pause
## menu (or any other menu) pauses the game, and everything animated by
## `game_time` freezes with it.
##
## To make a new shader pause-aware: add `global uniform float game_time;` and
## use it where you'd use TIME.

const PARAM := &"game_time"

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	RenderingServer.global_shader_parameter_set(PARAM, _time)
