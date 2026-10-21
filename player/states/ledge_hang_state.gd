class_name LedgeHangState
extends PlayerState
## Hanging from a ledge edge, caught automatically while falling into one
## (see Player.find_ledge(), called from AirState). Deliberately minimal:
## every other move (roll/dive/pound, side flip, air steering, ...) is
## locked out just by this state never calling any of them — only crouch
## (drop down) and jump do anything here. Jump is a plain start_jump(), the
## exact same call GroundState makes — no scripted climb, you just jump off
## the wall like you would off the ground.

var _wall_normal := Vector3.FORWARD

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_wall_normal = _msg.get("wall_normal", Vector3.FORWARD)
	var hang_pos: Vector3 = _msg.get("hang_pos", p.global_position)
	p.velocity = Vector3.ZERO
	p.global_position = hang_pos
	p.face(-_wall_normal, -1.0)   # face into the wall you're hanging from
	p.can_dive = true   # dropping or jumping off counts as fresh footing, same as landing
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_LEDGE_HANG)

func physics_update(_delta: float) -> void:
	var p := player
	# Held in place — no drift, no gravity, no input-driven movement at all.
	p.velocity = Vector3.ZERO

	if Input.is_action_pressed(&"crouch_pound"):
		p.velocity.y = p.config.ledge_drop_speed
		machine.transition_to(&"Air")
		return

	if p.jump_buffer_t > 0.0:
		p.start_jump(p.config.jump_velocity)
