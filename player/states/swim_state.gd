class_name SwimState
extends PlayerState
## Buoyant free swim — entered/exited entirely by Player._update_water() once
## the player is submerged past config.water_swim_depth_ratio, not by
## anything this state itself checks. No gravity: horizontal input swims on
## the surface plane, holding jump rises, crouch_pound dives, and letting go
## of both just holds depth rather than sinking or floating on its own.
##
## There's only one vertical swim clip (ANIM_SWIM_VERTICAL) — diving reuses
## it flipped upside-down via PlayerVisual.set_upside_down() instead of
## needing a separate "swim down" animation. See that method's doc comment.

## Stroke sfx fire whenever whichever swim clip is currently playing crosses
## one of these points in its own loop — same "fire on phase crossing" idiom
## as GroundState's FOOTSTEP_PHASES/_update_footsteps(). Each swim clip's own
## loop runs ~4 seconds; a single phase point only fired a stroke once per
## full loop, which read as the sound having stopped entirely — four evenly
## spaced points instead gives roughly one stroke per second, same spacing
## reasoning as FOOTSTEP_PHASES.
const STROKE_PHASES := [0.0, 0.25, 0.5, 0.75]
var _stroke_phase := -1.0   ## last-seen phase, for edge-crossing detection — see _update_stroke_sfx()

## How often a wake ripple is left behind while paddling at the surface —
## see the horizontal-swim branch in physics_update(). Not tied to the
## stroke phase like the sfx above; a flat interval reads fine for a purely
## cosmetic trailing ring and is simpler than another phase-crossing check.
const WAKE_INTERVAL := 0.3
var _wake_t := 0.0
var _had_h := false         ## last frame's input state, to tell which axis was pressed most recently
var _had_v := false
var _axis_vertical := false  ## when both axes are held, true = vertical wins
var _prev_motion_mode := CharacterBody3D.MOTION_MODE_GROUNDED

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	p.can_dive = true
	p.swim_current = Vector3.ZERO
	# Whatever speed you were carrying in (a dive, a long fall, a running
	# jump off the shore) is killed outright rather than left to bleed off
	# via swim_accel/swim_vertical_accel — hitting the water is what stops
	# you, not the water's own drag over the next several frames.
	p.velocity = Vector3.ZERO
	# Floating mode: the lake bed, a bank or any slope is just a wall to slide
	# along, never a ramp to walk up. In the default grounded mode a swimmer
	# pushing into sloped ground got carried up it (and out of the water).
	_prev_motion_mode = p.motion_mode
	p.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_SWIM)
	p.effects.set_swim_bubbles(true)
	_stroke_phase = -1.0
	_wake_t = 0.0
	_had_h = false
	_had_v = false

func exit(_next: StringName) -> void:
	player.motion_mode = _prev_motion_mode
	player.swim_pitch = 0.0
	player.visual.set_upside_down(false)
	player.effects.set_swim_bubbles(false)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config

	# Jump launches you out of the water for real once you're already close
	# to resurfacing — a plain press near the top does it immediately, and
	# holding it to swim up (the vertical-input case below) does it the
	# instant that rise actually crosses into the margin too, instead of
	# requiring a fresh press right as you reach the top.
	if Input.is_action_pressed(&"jump") and p.water_submersion() <= c.water_swim_depth_ratio + c.swim_surface_jump_margin:
		# Without this, _update_water() (which runs before this very state
		# machine transition even takes effect, next physics frame) reads the
		# same still-"deep enough" submersion — global_position hasn't
		# actually moved yet — and immediately transitions straight back
		# into Swim before the jump's own upward speed ever clears the
		# surface. See Player.SWIM_EXIT_GRACE.
		p.swim_exit_cd = Player.SWIM_EXIT_GRACE
		p.start_jump(c.jump_velocity)
		return

	var input := p.input_dir()
	var vertical := 0.0
	if Input.is_action_pressed(&"jump"):
		vertical += 1.0
	if Input.is_action_pressed(&"crouch_pound"):
		vertical -= 1.0
	# One axis at a time: swimming is either across or up/down, never a diagonal.
	# If both are held, whichever was pressed most recently wins.
	var has_h := input.length() > 0.1
	var has_v := absf(vertical) > 0.1
	if has_h and not _had_h:
		_axis_vertical = false
	if has_v and not _had_v:
		_axis_vertical = true
	_had_h = has_h
	_had_v = has_v
	if has_h and has_v:
		if _axis_vertical:
			has_h = false
		else:
			has_v = false
			vertical = 0.0
	elif not has_v:
		vertical = 0.0

	# Held input uses the snappy rate (instant starts and direction changes);
	# letting go coasts to a stop at the gentler one.
	var target_h := input.normalized() * c.swim_speed if has_h else Vector3.ZERO
	if has_h:
		p.set_hvel(target_h)   # held input is instant: full speed in the new direction, no ramp
	else:
		p.set_hvel(p.get_hvel().move_toward(Vector3.ZERO, c.swim_accel * delta))
	var target_v := vertical * c.swim_vertical_speed
	if has_v:
		p.velocity.y = target_v
	else:
		p.velocity.y = move_toward(p.velocity.y, 0.0, c.swim_vertical_accel * delta)

	var h := p.get_hvel()
	# Rising/diving uses the straight up/down clip (diving flips it upside-down);
	# otherwise paddling across, or treading water when idle.
	var active_anim := PlayerVisual.ANIM_SWIM_IDLE
	p.swim_pitch = 0.0
	if has_v:
		p.visual.set_upside_down(vertical < 0.0)
		active_anim = PlayerVisual.ANIM_SWIM_VERTICAL
	elif h.length() > 0.1:
		p.visual.set_upside_down(false)
		active_anim = PlayerVisual.ANIM_SWIM
	else:
		p.visual.set_upside_down(false)
	p.visual.play(active_anim, 0.0)   # hard cut: a crossfade between the flat paddle pose and the flipped vertical pose swept through a backflip

	if h.length() > 0.1:
		p.face(h)   # no turning animation: snaps to the new heading

	# No stroke sound while idle (active_anim stays ANIM_SWIM_IDLE) — treading
	# water doesn't stroke. _update_stroke_sfx() resets cleanly either way.
	_update_stroke_sfx(p, active_anim if active_anim != PlayerVisual.ANIM_SWIM_IDLE else &"")

	# Wake ripple only while actually paddling at the surface — not while
	# treading water in place, and not while diving/rising vertically
	# (there's nothing at the surface to leave a wake in either case).
	var water := p.current_water()
	if active_anim == PlayerVisual.ANIM_SWIM:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_wake_t = WAKE_INTERVAL
			if water != null:
				p.effects.burst_water_wake(p.global_position, water.surface_world_y())
	else:
		_wake_t = 0.0

	# Keeps the air-bubble trail from visibly rising past the surface — see
	# PlayerEffects.update_bubble_ceiling()'s own doc comment. Every frame,
	# not just on enter(), since the margin to the surface keeps changing as
	# the player moves vertically through the water.
	p.effects.update_bubble_ceiling(water)

	# An orb's current rides on top of the swim input for a moment (see
	# Player.swim_off_orb()); it's added just for this move so it never
	# becomes part of the swim velocity itself.
	var push := p.swim_current
	p.swim_current = push.move_toward(Vector3.ZERO, Player.SWIM_CURRENT_DECAY * delta)
	p.velocity += push
	p.safe_move_and_slide()
	p.velocity -= push

## See STROKE_PHASES above — identical edge-crossing logic to
## GroundState._update_footsteps(), just against whichever clip (paddle or
## vertical) is actually driving the stroke right now, so a stroke timed to
## the vertical clip's own loop doesn't fire based on the paddle clip's
## leftover phase, or vice versa.
func _update_stroke_sfx(p: Player, active_anim: StringName) -> void:
	if active_anim == &"":
		_stroke_phase = -1.0
		return
	var phase := p.visual.anim_phase(active_anim)
	if phase < 0.0:
		_stroke_phase = -1.0
		return
	if _stroke_phase < 0.0:
		_stroke_phase = phase
		return
	var cur := phase
	if cur < _stroke_phase:
		cur += 1.0   # looped back around since the last frame
	for step in STROKE_PHASES:
		if (_stroke_phase <= step and step < cur) or (_stroke_phase <= step + 1.0 and step + 1.0 < cur):
			p.audio.play_swim_stroke()
	_stroke_phase = phase
