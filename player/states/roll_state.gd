class_name RollState
extends PlayerState
## Hold the roll button to keep rolling. Speed bleeds off; once it drops below
## roll_stop_speed (or the button is released after the minimum time) you stand up.

var _elapsed := 0.0
var _finished_t := 0.0   ## how long the roll has wanted to end but couldn't stand up —
                          ## see the can_stand() escape hatch at the bottom of physics_update()

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_elapsed = 0.0
	_finished_t = 0.0
	p.set_crouching(true)
	# A deliberately-triggered move always takes over immediately, regardless
	# of whatever reaction pose (a wall-bounce tumble, a side flip, ...) might
	# still be protected from right before this — see PlayerVisual.play()'s
	# hold guard.
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_ROLL)
	p.audio.play_roll_start()
	var dir := p.input_dir()
	if dir.length() < 0.1:
		dir = p.facing
	p.face(dir)
	p.set_hvel(dir.normalized() * p.config.roll_speed)

func exit(_next: StringName) -> void:
	player.roll_cd = player.config.roll_cooldown
	player.audio.set_rolling(false)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	# A no-op once already rolling; resumes the loop on its own once a
	# wall-collision reaction pose (play_hold, below) has run its course.
	p.visual.play(PlayerVisual.ANIM_ROLL)
	# Roll + jump = long jump (works at any point of the roll).
	if p.jump_buffer_t > 0.0:
		if p.can_stand():
			var dir := p.get_hvel()
			dir = dir.normalized() if dir.length() > 0.1 else p.facing
			p.set_hvel(dir * c.long_jump_speed)
			p.velocity.y = c.long_jump_velocity
			p.jump_buffer_t = 0.0
			machine.transition_to(&"LongJump")
			return
		print("[JumpDebug] Roll long-jump suppressed: no headroom (can_stand() false)")

	var input := p.input_dir()
	var h := p.get_hvel()
	if input.length() > 0.1:   # light steering
		var lim := c.roll_steer * delta
		h = h.rotated(Vector3.UP, clampf(h.signed_angle_to(input, Vector3.UP), -lim, lim))
	# Slope awareness: gravity's own component along the floor pulls a roll
	# downhill (and resists it going uphill), scaling up with steepness just
	# like GroundState's forced slide does for standing — blended additively
	# into the roll's existing momentum here rather than overriding it, so a
	# gentle slope just nudges your line while a steep one can overpower your
	# steering entirely, same as it would rolling a real ball down a hill.
	if p.is_on_floor():
		var angle := p.get_floor_angle()
		if angle > 0.001:
			var normal := p.get_floor_normal()
			var down_slope := Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
			if down_slope.length() > 0.001:
				h += down_slope.normalized() * (c.gravity * sin(angle)) * delta
	var spd := maxf(0.0, h.length() - c.roll_decay * delta)
	h = h.normalized() * spd if spd > 0.0 else Vector3.ZERO
	p.set_hvel(h)
	# Tumble loop fades in/out with the roll's own current speed — 0 right
	# at roll_stop_speed (about to end), full by roll_speed (fresh launch).
	p.audio.set_rolling(true, inverse_lerp(c.roll_stop_speed, c.roll_speed, spd))
	p.face(h, delta)
	p.velocity.y = -1.0
	var prev_h := p.get_hvel()
	p.move_and_slide()

	# Same launch-into-air bounce Dive/LongJump use, just reachable from the
	# ground — pops you upward with the collision pose instead of just
	# stopping dead against the wall.
	if p.try_wall_bounce(prev_h, true, PlayerVisual.ANIM_ROLL_COLLISION, c.roll_collision_time, true):
		return

	if not p.is_on_floor():
		machine.transition_to(&"Air")
		return
	_elapsed += delta
	var held := Input.is_action_pressed(&"roll_dive")
	var finished := spd < c.roll_stop_speed or (_elapsed >= c.roll_time and not held)
	# Normally gated on can_stand() so you don't pop up through a low ceiling.
	# But rolling onto the far side of a slope/valley can pin you somewhere
	# with headroom too tight to ever pass that check — at that point the roll
	# has already stopped (finished stays true forever) with nothing else in
	# this state able to change it, which would otherwise soft-lock you
	# crouch-rolling in place forever. Standing up anyway after a short grace
	# period is the safe fallback: GroundState/CrouchState's own enter() only
	# uncrouches if can_stand() passes there too, so a genuinely tight spot
	# just leaves you crouched (fully controllable) instead of stuck rolling.
	_finished_t = _finished_t + delta if finished else 0.0
	if finished and (p.can_stand() or _finished_t >= 0.3):
		machine.transition_to(&"Crouch" if Input.is_action_pressed(&"crouch_pound") else &"Ground")
