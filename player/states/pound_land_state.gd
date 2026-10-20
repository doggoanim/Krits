class_name PoundLandState
extends PlayerState
## Short recovery after a ground pound. Jumping here — or anywhere during the
## windup/slam that preceded it (see PoundState), or in the brief jump-buffer
## window right at the moment of landing — performs the high pound jump.

var _t := 0.0

func enter(_prev: StringName, msg: Dictionary = {}) -> void:
	_t = player.config.pound_recover
	player.set_hvel(Vector3.ZERO)
	player.visual.cancel_hold()   # see RollState.enter()'s identical comment
	player.visual.play(PlayerVisual.ANIM_POUND_LAND)
	player.audio.play_pound_land()
	if player.camera_rig:
		player.camera_rig.shake(0.25)
	if msg.get("jump_queued", false):
		# A jump pressed during the fall (see PoundState.physics_update()) —
		# honor it right away instead of making the player land, let go of
		# jump, and press it again inside the recovery window. If this is a
		# no-op (e.g. the player landed in slime), physics_update()'s own
		# jump_buffer_t check below still covers a press made during recovery.
		player.start_jump(player.config.pound_jump_velocity, true)

func physics_update(delta: float) -> void:
	var p := player
	if p.jump_buffer_t > 0.0:
		p.start_jump(p.config.pound_jump_velocity, true)
		return
	p.velocity = Vector3(0.0, -1.0, 0.0)
	p.move_and_slide()
	_t -= delta
	if _t <= 0.0 or not p.is_on_floor():
		machine.transition_to(&"Ground")
