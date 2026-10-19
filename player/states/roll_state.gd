class_name RollState
extends PlayerState
## Hold the roll button to keep rolling. Speed bleeds off; once it drops below
## roll_stop_speed (or the button is released after the minimum time) you stand up.

var _elapsed := 0.0

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_elapsed = 0.0
	p.set_crouching(true)
	p.visual.play(PlayerVisual.ANIM_ROLL)
	var dir := p.input_dir()
	if dir.length() < 0.1:
		dir = p.facing
	p.face(dir)
	p.set_hvel(dir.normalized() * p.config.roll_speed)

func exit(_next: StringName) -> void:
	player.roll_cd = player.config.roll_cooldown

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	# Roll + jump = long jump (works at any point of the roll).
	if p.jump_buffer_t > 0.0 and p.can_stand():
		var dir := p.get_hvel()
		dir = dir.normalized() if dir.length() > 0.1 else p.facing
		p.set_hvel(dir * c.long_jump_speed)
		p.velocity.y = c.long_jump_velocity
		p.jump_buffer_t = 0.0
		machine.transition_to(&"LongJump")
		return

	var input := p.input_dir()
	var h := p.get_hvel()
	if input.length() > 0.1:   # light steering
		var lim := c.roll_steer * delta
		h = h.rotated(Vector3.UP, clampf(h.signed_angle_to(input, Vector3.UP), -lim, lim))
	var spd := maxf(0.0, h.length() - c.roll_decay * delta)
	h = h.normalized() * spd if spd > 0.0 else Vector3.ZERO
	p.set_hvel(h)
	p.face(h, delta)
	p.velocity.y = -1.0
	p.move_and_slide()

	if not p.is_on_floor():
		machine.transition_to(&"Air")
		return
	_elapsed += delta
	var held := Input.is_action_pressed(&"roll_dive")
	var finished := spd < c.roll_stop_speed or (_elapsed >= c.roll_time and not held)
	if finished and p.can_stand():
		machine.transition_to(&"Crouch" if Input.is_action_pressed(&"crouch_pound") else &"Ground")
