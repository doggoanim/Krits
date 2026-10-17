class_name GroundState
extends PlayerState

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	if player.can_stand():
		player.set_crouching(false)
	player.can_dive = true

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	if p.jump_buffer_t > 0.0:
		p.start_jump(c.jump_velocity)
		return
	if Input.is_action_just_pressed(&"roll_dive") and p.roll_cd <= 0.0:
		machine.transition_to(&"Roll")
		return
	if Input.is_action_pressed(&"crouch_pound"):
		machine.transition_to(&"Crouch")
		return

	var input := p.input_dir()
	var moving := input.length() > 0.1
	var h := p.get_hvel().move_toward(input * c.walk_speed, (c.ground_accel if moving else c.ground_decel) * delta)
	p.set_hvel(h)
	if moving:
		p.face(input, delta)
	p.velocity.y = -1.0
	p.move_and_slide()
	if not p.is_on_floor():
		machine.transition_to(&"Air")
