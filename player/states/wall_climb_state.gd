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
var _at_top := false   ## true once trying to climb further up finds no more wall, OR the
                        ## wall_climb_max_height cap is reached — see physics_update()'s
                        ## climb-up probe and the jump handling below
var _grab_height := 0.0   ## _attach_point.y at the moment of grabbing — wall_climb_max_height
                           ## is measured from here, not from world origin

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_normal = _msg.get("normal", Vector3.FORWARD)
	_attach_point = _msg.get("point", p.global_position)
	_at_top = false
	_grab_height = _attach_point.y
	# Ease the very first grab in too, not just later corner wraps: seed the
	# "from" pair at the player's actual current spot — same normal as the
	# target, so _apply_position()'s blend below only moves the position, not
	# the facing/rotation — and start the blend timer fresh, instead of
	# snapping straight to the wall. physics_update()'s own per-frame
	# p.face(..., delta) call (not the -1.0 "snap" form) then eases the turn
	# into facing the wall too, for free.
	_wrap_from_normal = _normal
	_wrap_from_point = p.global_position - _normal * p.config.wall_hug_distance
	_wrap_t = 0.0
	p.velocity = Vector3.ZERO
	p.can_dive = true
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_WALL_CLIMB_IDLE)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config

	var right := _wall_right(_normal)
	# Raw action strengths, not p.input_dir() — wall-climb steering is fixed
	# to the controls themselves (A always strafes one way, D the other),
	# not reinterpreted relative to wherever the camera happens to be looking.
	var strafe := Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left")
	var climb := Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back")
	var move := right * strafe + Vector3.UP * climb
	if move.length() > 1.0:
		move = move.normalized()
	var moving := move.length() > 0.05

	if moving:
		var tentative := _attach_point + move * c.wall_climb_speed * delta
		# Climbing down shouldn't be able to push the player through the floor
		# at the base of the wall. Cast from the player's last-known-good spot
		# (still above ground), not from `tentative` itself — once a frame's
		# step lands below the floor, a downward-only ray from there would
		# never see the ground it just passed through. _attach_point.y tracks
		# the player's own origin height (see find_climbable_wall()), so the
		# result clamps straight onto tentative.y with no extra offset.
		var ground = p.ground_height_below(_attach_point, c.wall_climb_speed * delta + 0.2)
		if ground != null and tentative.y < ground:
			tentative.y = ground
		# A hard cap independent of the wall's own collision height — some
		# climbable walls simply have collision that reaches much further up
		# than the climbable-looking art (a tower, a wall that continues
		# into geometry overhead, ...), so relying only on "the probe found
		# nothing" to call it the top let the player keep climbing well past
		# where it should stop. Clamping tentative.y here means the player
		# can never actually ask to go higher than the cap in the first
		# place, regardless of what's physically still there above it.
		var top_limit := _grab_height + c.wall_climb_max_height
		var height_capped := climb > 0.0 and tentative.y >= top_limit
		if height_capped:
			tentative.y = top_limit
		# Only let the search wrap onto a different wall while the player is
		# actually steering sideways — pure up/down climbing should only ever
		# re-check the same wall it's already on, so running out of it (the
		# actual top/bottom) reliably comes back empty instead of possibly
		# latching onto some unrelated nearby climbable surface.
		var found := p.probe_wall_near(tentative, _normal, strafe, absf(strafe) > 0.05)
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
			if climb > 0.0:
				# Still "at the top" if we only got this far because the
				# height cap clamped us there, even though the wall itself
				# keeps going — not just when the wall genuinely ran out.
				_at_top = height_capped
		elif climb > 0.0:
			# Tried to climb further up and found nothing there — the top
			# edge of the wall. Only set on an actual upward attempt (not
			# sideways movement, which says nothing about what's above), so
			# a jump pressed right after still reads as "at the top".
			_at_top = true
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
		if _at_top:
			# Nothing left to grab above — this reads as stepping off the top
			# of the wall, not kicking off of it: a normal straight-up jump
			# instead of jump_off_wall()'s horizontal push-away, just held in
			# the roll pose for a beat afterward, the same trick GroundState's
			# steep-slope jump uses.
			p.can_dive = true
			p.wall_climb_cd = Player.WALL_CLIMB_REGRAB_COOLDOWN
			p.start_jump(c.jump_velocity)
			p.visual.play_hold(PlayerVisual.ANIM_ROLL, c.slope_jump_roll_hold_time)
		else:
			p.jump_off_wall(_normal)

func _apply_position(normal: Vector3, point: Vector3) -> void:
	player.global_position = point + normal * player.config.wall_hug_distance

## The player's screen/keyboard right while attached to a wall with this
## normal. While climbing, the player faces -normal (into the wall — see
## enter()/_apply_position() callers), and screen-right for someone facing
## `fwd` is fwd.cross(UP) — so right = (-normal).cross(UP) = UP.cross(normal).
## Getting this backwards (e.g. normal.cross(UP), the old version) doesn't
## matter when steering is run through a camera-relative dot product, since
## that self-corrects for either sign — but now that strafe is a raw,
## camera-independent D-minus-A value (see physics_update()), the actual
## handedness here is what decides whether D is really "right".
func _wall_right(normal: Vector3) -> Vector3:
	var right := Vector3.UP.cross(normal)
	return right.normalized() if right.length() > 0.01 else Vector3.RIGHT
