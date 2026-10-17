class_name LongJumpState
extends PlayerState

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	player.visual.set_pose(&"long_jump")

func exit(_next: StringName) -> void:
	player.visual.set_pose(&"")

func physics_update(delta: float) -> void:
	var p := player
	if Input.is_action_just_pressed(&"crouch_pound"):
		machine.transition_to(&"Pound")
		return
	p.air_control(delta)
	p.face(p.get_hvel(), delta)
	p.apply_gravity(delta, p.config.long_jump_gravity_mult)
	var prev_h := p.get_hvel()
	p.move_and_slide()
	if p.try_wall_bounce(prev_h, true):
		return
	if p.is_on_floor():
		machine.transition_to(&"Ground")
