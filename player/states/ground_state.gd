class_name GroundState
extends PlayerState

## Slide state — carries you forward on an eased-out curve (holds speed
## early, sheds most of it near the end) rather than a flat deceleration, so
## it reads as a real skid instead of an instant brake.
var _slide_t := 0.0
var _slide_dir := Vector3.ZERO
var _slide_start_speed := 0.0
var _slide_is_turn := false   ## true when the current/most recent skid came from reversing
                               ## direction rather than just stopping — gates the side-flip trick
var _turn_flip_t := 0.0   ## >0 for a short grace window after a turn-skid starts; the side-flip's
                           ## own jump-buffer-style timer, independent of the slide pose's animation
                           ## hold (see physics_update) so the trick doesn't depend on exact frame
                           ## timing between the two
var _move_t := 0.0   ## how long you've been continuously moving — gates the slide below

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	if player.can_stand():
		player.set_crouching(false)
	player.can_dive = true
	_move_t = 0.0

func exit(_next: StringName) -> void:
	player.effects.set_running_dust(false)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	var input := p.input_dir()
	var moving := input.length() > 0.1
	var prev_h := p.get_hvel()
	var was_sliding := p.visual.is_holding()
	_turn_flip_t = maxf(0.0, _turn_flip_t - delta)

	# Fast enough stop or sharp enough reversal triggers a brief slide. Only
	# the stop case is gated by slide_min_move_time (a quick stick tap
	# shouldn't skid to a stop) — a sharp direction change slides regardless
	# of how long you'd been moving, same as before. Checked here (before the
	# jump branch below) so a jump pressed on the very frame the skid starts
	# still sees it.
	var stopping := not moving and _move_t >= c.slide_min_move_time
	var reversing := moving and prev_h.normalized().dot(input.normalized()) <= c.slide_turn_dot
	var starting_slide := not was_sliding and prev_h.length() >= c.slide_min_speed and (stopping or reversing)
	if starting_slide:
		_slide_is_turn = reversing
		if reversing:
			_turn_flip_t = c.side_flip_input_window

	# Jumping out of a skid-turn (reversing, not just stopping) does a Mario
	# 64-style side flip toward the new direction instead of a plain jump.
	# Gated by _turn_flip_t rather than the slide pose's own animation hold —
	# a dedicated grace window, same idiom as jump_buffer_t/coyote, so the
	# trick doesn't depend on landing the jump press on the exact frames the
	# slide animation happens to still be playing.
	if p.jump_buffer_t > 0.0:
		if _turn_flip_t > 0.0 and _slide_is_turn:
			p.start_side_flip(input)
		else:
			p.start_jump(c.jump_velocity)
		return
	if Input.is_action_just_pressed(&"roll_dive") and p.roll_cd <= 0.0:
		machine.transition_to(&"Roll")
		return
	if Input.is_action_pressed(&"crouch_pound"):
		machine.transition_to(&"Crouch")
		return

	# While the slide plays (play_hold protects the pose) you can't steer or
	# accelerate, just carry your existing momentum forward along an easing curve.
	if starting_slide:
		p.visual.play_hold(PlayerVisual.ANIM_SLIDE, c.slide_time)
		was_sliding = true
		_slide_t = 0.0
		_slide_dir = prev_h.normalized()
		_slide_start_speed = prev_h.length()
	_move_t = _move_t + delta if moving else 0.0

	var h: Vector3
	if was_sliding:
		_slide_t += delta
		# Ease-out: barely slows at first, sheds most of its speed in the
		# last stretch — 1 - frac^2 so the deceleration rate itself ramps up.
		var frac := clampf(_slide_t / c.slide_time, 0.0, 1.0)
		h = _slide_dir * (_slide_start_speed * (1.0 - frac * frac))
	else:
		var speed := c.walk_speed * (Player.SLIME_SPEED_MULT if p.is_slimed() else 1.0)
		h = prev_h.move_toward(input * speed, (c.ground_accel if moving else c.ground_decel) * delta)
	p.set_hvel(h)
	if moving and not was_sliding:
		p.face(input, delta)
	p.visual.play(PlayerVisual.ANIM_RUN if moving else PlayerVisual.ANIM_IDLE)
	p.effects.set_running_dust(moving and not was_sliding)
	p.velocity.y = -1.0
	p.move_and_slide()
	if not p.is_on_floor():
		machine.transition_to(&"Air")
