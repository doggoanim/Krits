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
	var prev_h := p.get_hvel()
	var was_sliding := p.visual.is_holding()

	# Fast enough stop or sharp enough reversal triggers a brief slide — while
	# it plays (play_hold protects the pose) you can't steer or accelerate,
	# just skid to a stop on whatever momentum you already had.
	if not was_sliding and prev_h.length() >= c.slide_min_speed and \
			(not moving or prev_h.normalized().dot(input.normalized()) <= c.slide_turn_dot):
		p.visual.play_hold(PlayerVisual.ANIM_SLIDE, c.slide_time)
		was_sliding = true

	var h: Vector3
	if was_sliding:
		var spd := maxf(0.0, prev_h.length() - c.ground_decel * delta)
		h = prev_h.normalized() * spd if spd > 0.0 else Vector3.ZERO
	else:
		h = prev_h.move_toward(input * c.walk_speed, (c.ground_accel if moving else c.ground_decel) * delta)
	p.set_hvel(h)
	if moving and not was_sliding:
		p.face(input, delta)
	p.visual.play(PlayerVisual.ANIM_RUN if moving else PlayerVisual.ANIM_IDLE)
	p.velocity.y = -1.0
	p.move_and_slide()
	if not p.is_on_floor():
		machine.transition_to(&"Air")
