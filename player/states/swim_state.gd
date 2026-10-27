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

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	p.can_dive = true
	# Whatever speed you were carrying in (a dive, a long fall, a running
	# jump off the shore) is killed outright rather than left to bleed off
	# via swim_accel/swim_vertical_accel — hitting the water is what stops
	# you, not the water's own drag over the next several frames.
	p.velocity = Vector3.ZERO
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_SWIM)
	p.effects.set_swim_bubbles(true)
	_stroke_phase = -1.0
	_wake_t = 0.0

func exit(_next: StringName) -> void:
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
	var target_h := input.normalized() * c.swim_speed if input.length() > 0.1 else Vector3.ZERO
	p.set_hvel(p.get_hvel().move_toward(target_h, c.swim_accel * delta))

	var vertical := 0.0
	if Input.is_action_pressed(&"jump"):
		vertical += 1.0
	if Input.is_action_pressed(&"crouch_pound"):
		vertical -= 1.0
	p.velocity.y = move_toward(p.velocity.y, vertical * c.swim_vertical_speed, c.swim_vertical_accel * delta)

	var h := p.get_hvel()
	# Vertical pose takes priority over the horizontal one whenever actively
	# rising/diving — reads as "swimming up/down" rather than a flat paddle
	# that merely happens to also be gaining height. Treading water (neither
	# held) falls back to its own idle loop instead of the paddling one.
	var active_anim := PlayerVisual.ANIM_SWIM_IDLE
	if absf(vertical) > 0.1:
		p.visual.set_upside_down(vertical < 0.0)
		active_anim = PlayerVisual.ANIM_SWIM_VERTICAL
	elif h.length() > 0.1:
		p.visual.set_upside_down(false)
		active_anim = PlayerVisual.ANIM_SWIM
	else:
		p.visual.set_upside_down(false)
	p.visual.play(active_anim)

	if h.length() > 0.1:
		p.face(h, delta)

	# No stroke sound while idle (active_anim stays ANIM_SWIM_IDLE) — treading
	# water doesn't stroke. _update_stroke_sfx() resets cleanly either way.
	_update_stroke_sfx(p, active_anim if active_anim != PlayerVisual.ANIM_SWIM_IDLE else &"")

	# Wake ripple only while actually paddling at the surface — not while
	# treading water in place, and not while diving/rising vertically
	# (there's nothing at the surface to leave a wake in either case).
	if active_anim == PlayerVisual.ANIM_SWIM:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_wake_t = WAKE_INTERVAL
			var water := p.current_water()
			if water != null:
				p.effects.burst_water_wake(p.global_position, water.surface_world_y())
	else:
		_wake_t = 0.0

	p.safe_move_and_slide()

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
