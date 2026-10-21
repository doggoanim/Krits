class_name WallClimbState
extends PlayerState
## Free-direction climbing on specially marked walls (Player.CLIMBABLE_MASK —
## see find_climbable_wall()). Full 2D movement across the wall's own
## surface: strafe left/right, climb up/down, any combination. Every other
## move is locked out just by this state never calling any of them.
##
## Staying stuck to the wall and wrapping around a corner onto an adjacent
## climbable wall are the SAME operation here — every frame, Player.
## probe_wall_near() looks for a climbable surface near where you're trying
## to move, trying the current normal first (biased toward whichever way
## you're actually steering) and then that direction rotated by increasing
## angles. A flat wall just keeps re-hitting the same normal; a corner's
## probe comes back with a different one, and that's the wrap — eased in
## over wall_wrap_time (see _normal/_attach_point vs. the "_wrap_from_*"
## pair below) rather than snapped to instantly.

var _normal := Vector3.FORWARD      ## the current/target wall — authoritative for steering
var _attach_point := Vector3.ZERO
var _wrap_from_normal := Vector3.FORWARD   ## where a corner transition eased FROM
var _wrap_from_point := Vector3.ZERO
var _wrap_t := 1.0   ## 0 = just started easing into _normal/_attach_point, 1 = fully settled there

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_normal = _msg.get("normal", Vector3.FORWARD)
	_attach_point = _msg.get("point", p.global_position)
	_wrap_from_normal = _normal
	_wrap_from_point = _attach_point
	_wrap_t = 1.0
	p.velocity = Vector3.ZERO
	p.can_dive = true
	_apply_position(_normal, _attach_point)
	p.face(-_normal, -1.0)
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_WALL_CLIMB_IDLE)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config

	var right := _wall_right(_normal)
	var strafe := p.input_dir().dot(right)
	var climb := Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back")
	var move := right * strafe + Vector3.UP * climb
	if move.length() > 1.0:
		move = move.normalized()
	var moving := move.length() > 0.05

	if moving:
		var tentative := _attach_point + move * c.wall_climb_speed * delta
		var found := p.probe_wall_near(tentative, _normal, strafe)
		if not found.is_empty():
			if found.normal.dot(_normal) < 0.99:
				# A meaningfully different normal than what we're currently
				# shown at — a real corner transition, not just floating-point
				# noise on a flat wall. Start (or restart) the ease from
				# wherever we're actually currently displayed, not from the
				# old target, so a second wrap arriving mid-ease doesn't jump.
				_wrap_from_normal = _wrap_from_normal.slerp(_normal, _wrap_t)
				_wrap_from_point = _wrap_from_point.lerp(_attach_point, _wrap_t)
				_wrap_t = 0.0
			_attach_point = found.point
			_normal = found.normal
		# If nothing climbable is found near where we tried to go, treat it
		# like a solid edge and just don't move that frame — same fallback
		# as any other blocked movement, rather than falling off the first
		# untagged border you reach.

	_wrap_t = minf(1.0, _wrap_t + delta / maxf(c.wall_wrap_time, 0.001))
	var shown_normal := _normal if _wrap_t >= 1.0 else _wrap_from_normal.slerp(_normal, _wrap_t).normalized()
	var shown_point := _attach_point if _wrap_t >= 1.0 else _wrap_from_point.lerp(_attach_point, _wrap_t)
	_apply_position(shown_normal, shown_point)
	p.face(-shown_normal, delta)
	p.velocity = Vector3.ZERO
	p.visual.play(PlayerVisual.ANIM_WALL_CLIMB if moving else PlayerVisual.ANIM_WALL_CLIMB_IDLE)

	if Input.is_action_pressed(&"crouch_pound"):
		# A real push away from the wall, not just zero velocity — and the
		# same regrab cooldown jump_off_wall() uses, since without it
		# AirState's own find_climbable_wall() check (still facing the same
		# wall, barely any distance covered yet) would just grab it straight
		# back on the very next frame.
		p.velocity = -_normal * c.wall_release_push
		p.velocity.y = c.wall_drop_speed
		p.wall_climb_cd = Player.WALL_CLIMB_REGRAB_COOLDOWN
		machine.transition_to(&"Air")
		return

	if p.jump_buffer_t > 0.0:
		p.jump_off_wall(_normal)

func _apply_position(normal: Vector3, point: Vector3) -> void:
	player.global_position = point + normal * player.config.wall_hug_distance

## A horizontal "sideways along the wall" axis for `normal` — arbitrary in
## the sense that which way ends up "right" vs "left" isn't guaranteed to
## match a given wall's own art/orientation, but it's consistent frame to
## frame, which is all steering here actually needs.
func _wall_right(normal: Vector3) -> Vector3:
	var right := normal.cross(Vector3.UP)
	return right.normalized() if right.length() > 0.01 else Vector3.RIGHT
