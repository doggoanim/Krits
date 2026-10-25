class_name PoundState
extends PlayerState

var _t := 0.0
var _slamming := false
var _jump_queued := false   ## a jump pressed anytime during windup/slam — see physics_update()

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	_t = player.config.pound_windup
	_slamming = false
	_jump_queued = false
	player.velocity = Vector3.ZERO
	player.visual.cancel_hold()   # see RollState.enter()'s identical comment
	player.visual.play(PlayerVisual.ANIM_POUND)
	player.audio.play_pound_ready()

func physics_update(delta: float) -> void:
	var p := player
	# Neither windup nor the slam itself handle jump input — the fall is
	# comfortably longer than the ordinary jump_buffer_t window, so a press
	# anywhere in here (very natural: players reach for the pound-jump combo
	# by pressing jump as soon as they see the slam connect, not after) would
	# otherwise just decay away and be silently dropped before PoundLand ever
	# gets a chance to see it. Remembered here instead and handed to
	# PoundLandState on landing (see transition_to below / PoundLandState.enter()).
	if Input.is_action_just_pressed(&"jump"):
		_jump_queued = true
	if not _slamming:
		_t -= delta
		p.velocity = Vector3.ZERO
		if _t <= 0.0:
			_slamming = true
			p.velocity.y = -p.config.pound_speed
		return
	p.safe_move_and_slide()
	if p.is_on_floor():
		machine.transition_to(&"PoundLand", {"jump_queued": _jump_queued})
