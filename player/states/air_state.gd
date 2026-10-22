class_name AirState
extends PlayerState

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	if player.can_stand():
		player.set_crouching(false)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	if p.jump_buffer_t > 0.0 and p.coyote > 0.0:
		p.start_jump(c.jump_velocity)
		return
	if Input.is_action_just_pressed(&"roll_dive") and p.can_dive:
		machine.transition_to(&"Dive")
		return
	if Input.is_action_just_pressed(&"crouch_pound"):
		machine.transition_to(&"Pound")
		return

	var wall := p.find_climbable_wall()
	if not wall.is_empty():
		p.grab_wall(wall.point, wall.normal)
		return

	# A wall bounce's reaction pose also locks out steering for the same
	# window — you're along for the bounce's arc until it ends. A purely
	# cosmetic hold (the top-of-wall jump's roll pose) doesn't count — see
	# is_holding_control().
	if not p.visual.is_holding_control():
		p.air_control(delta)
		var input := p.input_dir()
		if input.length() > 0.1:
			p.face(input, delta)
	p.apply_gravity(delta)
	# A wall-bounce collision pose protects itself via play_hold — this call
	# is simply ignored for the moment and takes back over once it expires.
	p.visual.play(p.visual.jump_start_anim() if p.velocity.y > c.fall_pose_velocity else PlayerVisual.ANIM_FALLING)
	p.move_and_slide()
	# velocity.y <= 0.0 matters here, not just is_on_floor(): right as a jump
	# starts, move_and_slide() can report a same-frame false-positive floor
	# touch resolving the body's resting overlap, even while it's already
	# moving up — same underlying quirk _update_floor_snap() exists for, just
	# a case that floor_snap_length alone doesn't cover. Without this guard,
	# that false positive sent the state back to Ground, whose own -1.0
	# floor-hug bias stomped the jump's velocity before Air could reclaim it
	# the very next frame — the jump's effects/sound played but it never
	# actually left the ground. Only treat it as a real landing while
	# actually falling.
	if p.is_on_floor() and p.velocity.y <= 0.0:
		machine.transition_to(&"Ground")
