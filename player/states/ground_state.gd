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
	# A sharp enough reversal at speed gets a brief slide reaction before the
	# usual run/idle pose takes back over (play_hold protects it meanwhile).
	if moving and prev_h.length() >= c.slide_min_speed \
			and prev_h.normalized().dot(input.normalized()) <= c.slide_turn_dot:
		p.visual.play_hold(PlayerVisual.ANIM_SLIDE, c.slide_time)
	var h := prev_h.move_toward(input * c.walk_speed, (c.ground_accel if moving else c.ground_decel) * delta)
	p.set_hvel(h)
	if moving:
		p.face(input, delta)
	p.visual.play(PlayerVisual.ANIM_RUN if moving else PlayerVisual.ANIM_IDLE)
	p.velocity.y = -1.0
	p.move_and_slide()
	if not p.is_on_floor():
		machine.transition_to(&"Air")
