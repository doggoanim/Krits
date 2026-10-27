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

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	p.can_dive = true
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_SWIM)
	_stroke_phase = -1.0

func exit(_next: StringName) -> void:
	player.visual.set_upside_down(false)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config

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
