class_name PoleClimbState
extends PlayerState
## Mario 64-style pole climb: hold forward/back to climb up/down, jump to
## launch away from the pole. Every other move is locked out just by this
## state never calling any of them. Entered via Player.grab_pole(), called
## by Pole's own grab trigger — works from any prior state, airborne or on
## the ground, same as the original.

var _pole: Pole

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_pole = _msg.get("pole")
	if _pole == null or not is_instance_valid(_pole):
		# Shouldn't happen (grab_pole always passes one) — bail to a safe
		# state rather than "climbing" a pole that doesn't exist.
		machine.transition_to(&"Air")
		return
	p.velocity = Vector3.ZERO
	p.can_dive = true
	# Face toward the pole once, here, and leave it alone for the rest of the
	# climb — physics_update pins the player's XZ to the pole's own
	# centerline every frame, which would make a direction recomputed from
	# "player position minus pole position" degenerate to zero every frame.
	var to_pole := _pole.global_position - p.global_position
	to_pole.y = 0.0
	if to_pole.length() > 0.001:
		p.face(to_pole, -1.0)
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_POLE_HANG)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config
	if not is_instance_valid(_pole):
		machine.transition_to(&"Air")
		return

	# Pin horizontal position to the pole's own centerline every frame —
	# climbing reads as sliding cleanly along it, never drifting off.
	var pos := p.global_position
	pos.x = _pole.global_position.x
	pos.z = _pole.global_position.z

	var climb_dir := Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back")
	pos.y = clampf(pos.y + climb_dir * c.pole_climb_speed * delta,
		_pole.global_position.y, _pole.top_y())
	p.global_position = pos
	p.velocity = Vector3.ZERO

	if absf(climb_dir) > 0.1:
		p.visual.play(PlayerVisual.ANIM_POLE_CLIMB, 0.15, signf(climb_dir))
	else:
		p.visual.play(PlayerVisual.ANIM_POLE_HANG)

	# Climbed all the way down to the pole's own base — step off onto
	# whatever's underneath (almost always solid ground, by construction)
	# rather than hovering there forever. Reaching the TOP instead just
	# stops you there (clamped above) — unlike the base, a pole's top often
	# has nothing to step onto, so only jumping off ever leaves from there.
	if pos.y <= _pole.global_position.y + 0.01:
		machine.transition_to(&"Ground")
		return

	if p.jump_buffer_t > 0.0:
		var input := p.input_dir()
		var away := Vector3(input.x, 0.0, input.z)
		away = away.normalized() if away.length() > 0.1 else -p.facing
		p.jump_off_pole(away)
