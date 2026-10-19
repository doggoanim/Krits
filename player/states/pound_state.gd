class_name PoundState
extends PlayerState

var _t := 0.0
var _slamming := false

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	_t = player.config.pound_windup
	_slamming = false
	player.velocity = Vector3.ZERO
	player.visual.play(PlayerVisual.ANIM_POUND)

func physics_update(delta: float) -> void:
	var p := player
	if not _slamming:
		_t -= delta
		p.velocity = Vector3.ZERO
		if _t <= 0.0:
			_slamming = true
			p.velocity.y = -p.config.pound_speed
		return
	p.move_and_slide()
	if p.is_on_floor():
		machine.transition_to(&"PoundLand")
