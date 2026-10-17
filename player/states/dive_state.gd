class_name DiveState
extends PlayerState
## One wall bounce max (it does not re-grant the dive). Landing stops you instantly.

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	p.can_dive = false
	var dir := p.input_dir()
	if dir.length() < 0.1:
		dir = p.facing
	dir = dir.normalized()
	p.face(dir)
	p.set_hvel(dir * p.config.dive_speed)
	p.velocity.y = p.config.dive_up
	p.visual.set_pose(&"dive")

func exit(_next: StringName) -> void:
	player.visual.set_pose(&"")

func physics_update(delta: float) -> void:
	var p := player
	if Input.is_action_just_pressed(&"jump"):
		p.start_jump(p.config.dive_cancel_velocity, false)
		return
	p.apply_gravity(delta, 0.9)
	var prev_h := p.get_hvel()
	p.move_and_slide()
	if p.try_wall_bounce(prev_h, false):
		return
	if p.is_on_floor():
		p.set_hvel(Vector3.ZERO)
		machine.transition_to(&"Ground")
