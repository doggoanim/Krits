class_name CrouchState
extends PlayerState

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	player.set_crouching(true)

## A little bounce when standing back up normally — not when chaining into a
## roll or falling off a ledge, where the uncrouch pose would just get
## overridden by that state's own animation a frame later anyway.
func exit(next: StringName) -> void:
	if next == &"Ground":
		player.visual.squash_stretch(player.visual.uncrouch_bounce_y, player.visual.uncrouch_bounce_xz)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	if p.jump_buffer_t > 0.0:
		if p.can_stand():
			p.start_jump(c.jump_velocity)
			return
		print("[JumpDebug] Crouch jump suppressed: no headroom (can_stand() false)")
	if Input.is_action_just_pressed(&"roll_dive") and p.roll_cd <= 0.0:
		machine.transition_to(&"Roll")
		return
	if not Input.is_action_pressed(&"crouch_pound") and p.can_stand():
		machine.transition_to(&"Ground")
		return

	var input := p.input_dir()
	var moving := input.length() > 0.1
	var speed := c.crouch_speed * (Player.SLIME_SPEED_MULT if p.is_slimed() else 1.0)
	p.set_hvel(p.get_hvel().move_toward(input * speed, (c.ground_accel if moving else c.ground_decel) * delta))
	if moving:
		p.face(input, delta)
	p.visual.play(PlayerVisual.ANIM_CROUCH_WALK if moving else PlayerVisual.ANIM_CROUCH_IDLE)
	p.velocity.y = -1.0
	p.move_and_slide()
	if not p.is_on_floor():
		machine.transition_to(&"Air")
