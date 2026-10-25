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
	# Always takes over immediately — a dive can be triggered right out of
	# another move's own protected reaction pose (a wall-bounce tumble, the
	# skid/side-flip, an orb-hit attack, ...), and without this it would
	# either wait that pose out or (per play()'s hold guard) silently not
	# play at all until the old hold expired on its own.
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_DIVE)
	p.effects.set_dive_trail(true)
	p.audio.play_air_dive()

func exit(_next: StringName) -> void:
	player.effects.set_dive_trail(false)

func physics_update(delta: float) -> void:
	var p := player
	if p.jump_buffer_t > 0.0:
		p.set_hvel(Vector3.ZERO)   # cancel all momentum, same clean pop as an orb bounce
		p.start_jump(p.config.dive_cancel_velocity)
		return
	if Input.is_action_just_pressed(&"crouch_pound"):
		machine.transition_to(&"Pound")
		return
	# A climbable wall takes priority over the plain wall-bounce below — same
	# check/placement GroundState and AirState use, so diving straight into
	# one grabs it instead of cannoning off it. ignore_cooldown=true: diving
	# is a deliberate lunge, so jumping off a wall and immediately diving
	# back into it should climb again right away, not sit out the same
	# regrab cooldown that exists to stop an unintended instant re-stick.
	var wall := p.find_climbable_wall(true)
	if not wall.is_empty():
		p.grab_wall(wall.point, wall.normal, wall.body, true)
		return
	p.apply_gravity(delta, 0.9)
	var prev_h := p.get_hvel()
	p.safe_move_and_slide()
	if p.try_wall_bounce(prev_h, false, PlayerVisual.ANIM_ROLL, p.config.wall_bounce_roll_time):
		return
	if p.is_on_floor():
		p.set_hvel(Vector3.ZERO)
		machine.transition_to(&"Ground")
