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

	p.air_control(delta)
	var input := p.input_dir()
	if input.length() > 0.1:
		p.face(input, delta)
	p.apply_gravity(delta)
	p.visual.play(PlayerVisual.ANIM_JUMP_START if p.velocity.y > 0.0 else PlayerVisual.ANIM_FALLING)
	p.move_and_slide()
	if p.is_on_floor():
		machine.transition_to(&"Ground")
