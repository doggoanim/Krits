class_name AirState
extends PlayerState

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	if player.can_stand():
		player.set_crouching(false)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	if p.jump_buffer_t > 0.0 and p.coyote > 0.0:
		p.start_jump(c.jump_velocity)
		return
	if Input.is_action_just_pressed(&"roll_dive") and p.can_dive:
		machine.transition_to(&"Dive")
		return
	if Input.is_action_just_pressed(&"crouch_pound"):
		machine.transition_to(&"Pound")
		return

	# A wall bounce's reaction pose (play_hold, below) also locks out steering
	# for the same window — you're along for the bounce's arc until it ends.
	if not p.visual.is_holding():
		p.air_control(delta)
		var input := p.input_dir()
		if input.length() > 0.1:
			p.face(input, delta)
	p.apply_gravity(delta)
	# A wall-bounce collision pose protects itself via play_hold — this call
	# is simply ignored for the moment and takes back over once it expires.
	p.visual.play(p.visual.jump_start_anim() if p.velocity.y > c.fall_pose_velocity else PlayerVisual.ANIM_FALLING)
	p.move_and_slide()
	if p.is_on_floor():
		machine.transition_to(&"Ground")
