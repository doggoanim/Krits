class_name PoundLandState
extends PlayerState
## Short recovery after a ground pound. Jumping here (or just before landing,
## via the jump buffer) performs the high pound jump.

var _t := 0.0

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	_t = player.config.pound_recover
	player.set_hvel(Vector3.ZERO)
	if player.camera_rig:
		player.camera_rig.shake(0.25)

func physics_update(delta: float) -> void:
	var p := player
	if p.jump_buffer_t > 0.0:
		p.start_jump(p.config.pound_jump_velocity)
		return
	p.velocity = Vector3(0.0, -1.0, 0.0)
	p.move_and_slide()
	_t -= delta
	if _t <= 0.0 or not p.is_on_floor():
		machine.transition_to(&"Ground")
