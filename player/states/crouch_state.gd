class_name CrouchState
extends PlayerState

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	player.set_crouching(true)
	player.visual.play(PlayerVisual.ANIM_IDLE)   ## no dedicated crouch clip yet

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	if p.jump_buffer_t > 0.0 and p.can_stand():
		p.start_jump(c.jump_velocity)
		return
	if Input.is_action_just_pressed(&"roll_dive") and p.roll_cd <= 0.0:
		machine.transition_to(&"Roll")
		return
	if not Input.is_action_pressed(&"crouch_pound") and p.can_stand():
		machine.transition_to(&"Ground")
		return

	var input := p.input_dir()
	var moving := input.length() > 0.1
	p.set_hvel(p.get_hvel().move_toward(input * c.crouch_speed, (c.ground_accel if moving else c.ground_decel) * delta))
	if moving:
		p.face(input, delta)
	p.velocity.y = -1.0
	p.move_and_slide()
	if not p.is_on_floor():
		machine.transition_to(&"Air")
