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

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	p.can_dive = true
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_SWIM)

func exit(_next: StringName) -> void:
	player.visual.set_upside_down(false)
	player.audio.set_swimming(false)

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
	if absf(vertical) > 0.1:
		p.visual.set_upside_down(vertical < 0.0)
		p.visual.play(PlayerVisual.ANIM_SWIM_VERTICAL)
	elif h.length() > 0.1:
		p.visual.set_upside_down(false)
		p.visual.play(PlayerVisual.ANIM_SWIM)
	else:
		p.visual.set_upside_down(false)
		p.visual.play(PlayerVisual.ANIM_SWIM_IDLE)

	if h.length() > 0.1:
		p.face(h, delta)

	p.audio.set_swimming(h.length() > 0.1 or absf(vertical) > 0.1)

	p.safe_move_and_slide()
