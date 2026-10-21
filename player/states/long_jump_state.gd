class_name LongJumpState
extends PlayerState
## Roll + jump. Can cancel into a dive (consumes can_dive like any other air dive)
## or a ground pound, and wall-bounces re-grant the dive just like a normal jump.

var _jump_queued := false   ## a jump pressed anytime during the flight — see physics_update()

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	_jump_queued = false
	player.visual.cancel_hold()   # see RollState.enter()'s identical comment
	player.visual.play(PlayerVisual.ANIM_LONG_JUMP)
	player.effects.set_long_jump_trail(true)
	player.audio.play_long_jump()

func exit(_next: StringName) -> void:
	player.effects.set_long_jump_trail(false)

func physics_update(delta: float) -> void:
	var p := player
	# A long jump's arc comfortably outlasts jump_buffer_t's own short window
	# (0.12s) — this state never spends it, unlike every other airborne state
	# (Air/Dive/Roll all check it every frame), so a jump pressed mid-flight
	# — anticipating the landing, same as a real player would — just decays
	# away and is silently dropped by the time you actually land. Remembered
	# here instead and handed to Ground on landing, same idiom as PoundState's
	# own _jump_queued.
	if Input.is_action_just_pressed(&"jump"):
		_jump_queued = true
	if Input.is_action_just_pressed(&"roll_dive") and p.can_dive:
		machine.transition_to(&"Dive")
		return
	if Input.is_action_just_pressed(&"crouch_pound"):
		machine.transition_to(&"Pound")
		return
	p.air_control(delta)
	p.face(p.get_hvel(), delta)
	p.apply_gravity(delta, p.config.long_jump_gravity_mult)
	var prev_h := p.get_hvel()
	p.move_and_slide()
	if p.try_wall_bounce(prev_h, true, PlayerVisual.ANIM_ROLL, p.config.wall_bounce_roll_time):
		return
	if p.is_on_floor():
		machine.transition_to(&"Ground", {"jump_queued": _jump_queued})
