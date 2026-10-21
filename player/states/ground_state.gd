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
var _slope_sliding := false   ## true while forced into the steep-slope slide below — only used
                               ## to play the skid sound once per slide, not every single frame

## Footsteps are timed to the running clip's own loop (see PlayerVisual.run_phase())
## rather than a fixed timer: a footstep fires each time playback crosses one
## of these normalized points in the loop. Four evenly-spaced points (rather
## than the two actual foot-plants of a stride) reads better at this
## character's run speed — tune the count/spacing here if it's still off.
const FOOTSTEP_PHASES := [0.0, 0.25, 0.5, 0.75]
var _footstep_phase := -1.0   ## last-seen run_phase(), for edge-crossing detection; -1 = not tracking

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	if player.can_stand():
		player.set_crouching(false)
	player.can_dive = true
	_move_t = 0.0
	_slope_sliding = false
	if _msg.get("jump_queued", false):
		# A jump pressed sometime during a long jump's flight (see
		# LongJumpState) — re-arm the buffer so this state's own
		# physics_update, running right after this, picks it up and jumps
		# immediately instead of needing a fresh press on the exact landing frame.
		player.jump_buffer_t = player.config.jump_buffer

func exit(_next: StringName) -> void:
	player.effects.set_running_dust(false)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	var input := p.input_dir()
	var moving := input.length() > 0.1
	var prev_h := p.get_hvel()
	# Specifically the slide pose, not just "some hold is active" — a side
	# flip's own (longer) hold can still be running when it lands here, and
	# that isn't a skid in progress; treating it as one corrupted ground
	# movement with a stale _slide_dir/_slide_start_speed left over from
	# whatever the last real skid was, and locked out roll/pound for
	# however long the side-flip's pose happened to still have left.
	var was_sliding := p.visual.is_holding_anim(PlayerVisual.ANIM_SLIDE)
	_turn_flip_t = maxf(0.0, _turn_flip_t - delta)

	var wall := p.find_climbable_wall()
	if not wall.is_empty():
		p.grab_wall(wall.point, wall.normal)
		return

	# Too steep to stand or walk on at all — a separate mechanic from the
	# stop/turn skid below, checked first and completely skipping that
	# detection (and the side-flip trick it can arm) while it's active. A
	# held input direction that happens to look like a skid-turn reversal
	# relative to the slide's own downhill velocity must never be able to
	# steal a jump off the slide into a fixed-direction side flip — that
	# would both throw away the slide's momentum (start_side_flip replaces
	# horizontal velocity outright) and ignore request #2 below. A plain
	# jump never touches horizontal velocity, so it carries the slide's
	# momentum into the air for free.
	var floor_angle := p.get_floor_angle()
	var on_steep_slope := p.is_on_floor() and floor_angle >= deg_to_rad(c.slope_slide_angle_deg)
	if on_steep_slope:
		var normal := p.get_floor_normal()
		var down_slope := Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
		down_slope = down_slope.normalized() if down_slope.length() > 0.001 else p.facing
		if p.jump_buffer_t > 0.0:
			# On top of whatever momentum the slide had already built up
			# (start_jump() leaves horizontal velocity alone), kick you
			# further along the slide's own downhill direction — jumping off
			# a steep slope should read as leaping out of the slide, not
			# just a vertical hop that happens to still be drifting.
			p.set_hvel(p.get_hvel() + down_slope * c.slope_jump_push)
			p.start_jump(c.jump_velocity)
			# start_jump() picks one of the regular jump-start poses — override
			# it with the roll pose for a beat, since a jump launched out of a
			# fast downhill slide reads more like tumbling off it than a plain
			# standing hop. AirState's own per-frame animation takes back over
			# once the hold expires.
			p.visual.play_hold(PlayerVisual.ANIM_ROLL, c.slope_jump_roll_hold_time)
			return
		if not _slope_sliding:
			p.audio.play_skid()
		_slope_sliding = true
		p.face(down_slope, delta)
		var target_speed := c.slope_speed_for_angle(floor_angle)   ## steeper = faster, see PlayerConfig
		p.set_hvel(p.get_hvel().move_toward(down_slope * target_speed, c.slope_slide_accel * delta))
		p.visual.play(PlayerVisual.ANIM_SLIDE)
		p.velocity.y = -1.0
		p.move_and_slide()
		if not p.is_on_floor():
			machine.transition_to(&"Air")
		return
	_slope_sliding = false

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
		# Consumed either way, same as jump_buffer_t itself. _turn_flip_t only
		# ticks down while GroundState is actually running each frame, which it
		# isn't for the whole time a side flip is airborne — so without this,
		# landing from one and pressing jump again right away could re-trigger
		# ANOTHER side flip off the ORIGINAL skid's now-stale flags, with no
		# fresh turn behind it at all.
		_turn_flip_t = 0.0
		_slide_is_turn = false
		return

	# Locked out while the slide pose plays — same "carried along, no input
	# but jump" rule as steering/accelerating below. Roll (and by extension
	# the roll-into-jump long jump, which only starts from Roll) and the
	# crouch/pound both need their own footing, not a skid in progress.
	if not (was_sliding or starting_slide):
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
		p.audio.play_skid()
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
	if moving:
		p.visual.play(PlayerVisual.ANIM_RUN, 0.15, PlayerVisual.RUN_ANIM_SPEED)
	else:
		p.visual.play(PlayerVisual.ANIM_IDLE)
	var running := moving and not was_sliding
	p.effects.set_running_dust(running)
	if running:
		_update_footsteps(p)
	else:
		# Forget the last phase while stopped/sliding, so starting to run
		# again doesn't think it just wrapped around from wherever the run
		# clip happened to be paused at.
		_footstep_phase = -1.0
	p.velocity.y = -1.0
	p.move_and_slide()
	if not p.is_on_floor():
		machine.transition_to(&"Air")

## Fires a footstep each time the running clip's playback crosses one of
## FOOTSTEP_PHASES since the last frame, instead of restarting a fixed timer —
## so the sound always lands on the clip's own stride, no matter how its
## actual authored timing compares to a guessed interval. Handles the wrap
## from ~1.0 back to 0.0 at the end of each loop by unwrapping the current
## reading before comparing.
func _update_footsteps(p: Player) -> void:
	var phase := p.visual.run_phase()
	if phase < 0.0:
		_footstep_phase = -1.0
		return
	if _footstep_phase < 0.0:
		_footstep_phase = phase
		return
	var cur := phase
	if cur < _footstep_phase:
		cur += 1.0   # looped back around since the last frame
	for step in FOOTSTEP_PHASES:
		if (_footstep_phase <= step and step < cur) or (_footstep_phase <= step + 1.0 and step + 1.0 < cur):
			p.audio.play_footstep()
	_footstep_phase = phase
