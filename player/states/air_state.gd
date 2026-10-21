class_name AirState
extends PlayerState

var _diag_frames := 0   ## TEMP: see physics_update()'s print block, for the "jump sometimes
						 ## doesn't actually move you up" bug — remove once it's found

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	if player.can_stand():
		player.set_crouching(false)
	_diag_frames = 3

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	if p.jump_buffer_t > 0.0:
		if p.coyote > 0.0:
			p.start_jump(c.jump_velocity)
			return
		print("[JumpDebug] Air jump suppressed: coyote window expired")
	if Input.is_action_just_pressed(&"roll_dive") and p.can_dive:
		machine.transition_to(&"Dive")
		return
	if Input.is_action_just_pressed(&"crouch_pound"):
		machine.transition_to(&"Pound")
		return

	# Ledge grab: only while actually falling (not still rising out of a
	# jump), so a jump thrown at a nearby wall doesn't snag on its way up —
	# it only catches on the way back down, same as it reads in most
	# platformers.
	if p.velocity.y <= 0.0:
		var ledge := p.find_ledge()
		if not ledge.is_empty():
			machine.transition_to(&"LedgeHang", ledge)
			return

	# A wall bounce's reaction pose (play_hold, below) also locks out steering
	# for the same window — you're along for the bounce's arc until it ends.
	if not p.visual.is_holding():
		p.air_control(delta)
		var input := p.input_dir()
		if input.length() > 0.1:
			p.face(input, delta)
	var _diag := _diag_frames > 0
	if _diag:
		print("[JumpDebug] Air frame | vel.y before gravity=%.3f on_floor(stale)=%s" % [p.velocity.y, p.is_on_floor()])
	p.apply_gravity(delta)
	if _diag:
		print("[JumpDebug] Air frame | vel.y after gravity=%.3f" % p.velocity.y)
	# A wall-bounce collision pose protects itself via play_hold — this call
	# is simply ignored for the moment and takes back over once it expires.
	p.visual.play(p.visual.jump_start_anim() if p.velocity.y > c.fall_pose_velocity else PlayerVisual.ANIM_FALLING)
	p.move_and_slide()
	if _diag:
		print("[JumpDebug] Air frame | vel.y after move_and_slide=%.3f on_floor=%s global_y=%.3f" \
			% [p.velocity.y, p.is_on_floor(), p.global_position.y])
		_diag_frames -= 1
	if p.is_on_floor():
		machine.transition_to(&"Ground")
