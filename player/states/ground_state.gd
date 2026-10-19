class_name GroundState
extends PlayerState

## Slide state — carries you forward on an eased-out curve (holds speed
## early, sheds most of it near the end) rather than a flat deceleration, so
## it reads as a real skid instead of an instant brake.
var _slide_t := 0.0
var _slide_dir := Vector3.ZERO
var _slide_start_speed := 0.0
var _move_t := 0.0   ## how long you've been continuously moving — gates the slide below

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	if player.can_stand():
		player.set_crouching(false)
	player.can_dive = true
	_move_t = 0.0

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

	# Fast enough stop or sharp enough reversal triggers a brief slide — but
	# only after you've actually been moving for a bit, so a quick tap of the
	# stick doesn't skid. While it plays (play_hold protects the pose) you
	# can't steer or accelerate, just carry your existing momentum forward
	# along an easing curve.
	if not was_sliding and _move_t >= c.slide_min_move_time and prev_h.length() >= c.slide_min_speed and \
			(not moving or prev_h.normalized().dot(input.normalized()) <= c.slide_turn_dot):
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
		h = prev_h.move_toward(input * c.walk_speed, (c.ground_accel if moving else c.ground_decel) * delta)
	p.set_hvel(h)
	if moving and not was_sliding:
		p.face(input, delta)
	p.visual.play(PlayerVisual.ANIM_RUN if moving else PlayerVisual.ANIM_IDLE)
	p.velocity.y = -1.0
	p.move_and_slide()
	if not p.is_on_floor():
		machine.transition_to(&"Air")
