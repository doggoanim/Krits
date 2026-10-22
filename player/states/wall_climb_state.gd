class_name WallClimbState
extends PlayerState
## Free-direction climbing on specially marked walls (see Player.CLIMBABLE_MASK
## and Player.find_climbable_wall()). The player can move anywhere across the
## wall's own surface — strafe, climb up/down, or both at once — and every
## other move is locked out simply because this state never calls them.
##
## Position is set directly each frame (see _apply_position()), never through
## velocity/move_and_slide(). Staying stuck to the current wall and wrapping
## onto an adjacent one at a corner are the same operation: every frame,
## Player.probe_wall_near() looks for a climbable surface near wherever the
## player is trying to move, trying the current wall's normal first and then
## that direction rotated by increasing angles. A flat wall just keeps
## re-hitting the same normal; a corner's probe comes back with a different
## one — eased in over wall_wrap_time (see the "_ease_*" fields below) rather
## than snapped to instantly. The very first grab is eased in the same way.

var _normal := Vector3.FORWARD      ## the wall currently attached to
var _attach_point := Vector3.ZERO   ## a point on that wall, at the player's own origin height
                                     ## (not the probe's chest-height — see find_climbable_wall())
var _grab_height := 0.0             ## _attach_point.y at the moment of grabbing —
                                     ## wall_climb_max_height is measured from here
var _at_top := false                ## climbing up found nothing, or hit the height cap — makes
                                     ## jump a plain vertical hop instead of a wall-jump kick-off

var _ease_from_normal := Vector3.FORWARD   ## corner-wrap/grab transitions blend FROM this pair...
var _ease_from_point := Vector3.ZERO
var _ease_t := 1.0                         ## ...TO _normal/_attach_point, over wall_wrap_time

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_normal = _msg.get("normal", Vector3.FORWARD)
	_attach_point = _msg.get("point", p.global_position)
	_grab_height = _attach_point.y
	_at_top = false

	# Ease the grab in rather than snapping: seed the "from" pair at the
	# player's actual current spot — same normal as the target, so only
	# position blends, not facing (see _apply_position()) — and start the
	# blend fresh. physics_update()'s own per-frame p.face(..., delta) call
	# then eases the turn into facing the wall too, for free.
	_ease_from_normal = _normal
	_ease_from_point = p.global_position - _normal * p.config.wall_hug_distance
	_ease_t = 0.0

	p.velocity = Vector3.ZERO
	p.can_dive = true
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_WALL_CLIMB_IDLE)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config

	# Raw action strengths for strafe, not p.input_dir() — wall-climb
	# steering is fixed to the controls themselves (A always one way, D the
	# other), never reinterpreted relative to wherever the camera is looking.
	var strafe := Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left")
	var climb := Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back")
	var move: Vector3 = (_wall_right(_normal) * strafe + Vector3.UP * climb).limit_length(1.0)
	var moving := move.length() > 0.05

	if moving:
		_attempt_move(p, c, move, strafe, climb, delta)

	_ease_t = minf(1.0, _ease_t + delta / maxf(c.wall_wrap_time, 0.001))
	var shown_normal := _normal if _ease_t >= 1.0 else _ease_from_normal.slerp(_normal, _ease_t).normalized()
	var shown_point := _attach_point if _ease_t >= 1.0 else _ease_from_point.lerp(_attach_point, _ease_t)
	_apply_position(shown_normal, shown_point)
	p.face(-shown_normal, delta)
	p.velocity = Vector3.ZERO
	p.visual.play(PlayerVisual.ANIM_WALL_CLIMB if moving else PlayerVisual.ANIM_WALL_CLIMB_IDLE)

	if Input.is_action_pressed(&"crouch_pound"):
		_let_go(p, c)
		return
	if p.jump_buffer_t > 0.0:
		_jump(p, c)

## Tries to move `move * wall_climb_speed * delta` from the current attach
## point: clamped so it can't sink through the floor below or climb past
## wall_climb_max_height above, then checked against whatever's actually
## still climbable there (the same wall, a wrapped corner, or nothing).
func _attempt_move(p: Player, c: PlayerConfig, move: Vector3, strafe: float, climb: float, delta: float) -> void:
	var tentative := _attach_point + move * c.wall_climb_speed * delta

	# Don't let climbing down sink the player through the floor at the base
	# of the wall. The ray starts wall_hug_distance off the wall surface
	# (where the player's body actually sits — see _apply_position()), not
	# at _attach_point itself: that point sits ON the wall's own collision,
	# which shares the world-geometry layer this ray checks (a wall is
	# climbable *in addition to* its normal solid collision, not instead of
	# it) — starting the ray there could self-intersect the wall and return
	# a bogus "floor" height instead of the real one far below.
	var ray_origin := _attach_point + _normal * c.wall_hug_distance
	var ground = p.ground_height_below(ray_origin, c.wall_climb_speed * delta + 0.2)
	if ground != null and tentative.y < ground:
		tentative.y = ground

	# A hard cap on how far above the grab point the player can climb,
	# independent of how much further the wall's own collision actually
	# goes (some climbable walls reach well past their climbable-looking
	# art). Reaching it counts as "the top" just like genuinely running out
	# of wall, even though probe_wall_near() below would still find more.
	var top_limit := _grab_height + c.wall_climb_max_height
	var height_capped := climb > 0.0 and tentative.y >= top_limit
	if height_capped:
		tentative.y = top_limit

	var found := p.probe_wall_near(tentative, _normal, strafe)
	if found.is_empty():
		# Nothing climbable where we tried to go — same fallback as any
		# other blocked movement: just don't move this frame. Only an
		# upward attempt finding nothing actually means "the top"; sideways
		# movement finding nothing says nothing about what's above.
		if climb > 0.0:
			_at_top = true
		return

	if found.normal.dot(_normal) < 0.99:
		# A meaningfully different normal — a real corner, not floating-
		# point noise on a flat wall. Restart the ease from wherever we're
		# actually currently displayed, not the old target, so a second
		# wrap arriving mid-ease doesn't jump.
		_ease_from_normal = _ease_from_normal.slerp(_normal, _ease_t)
		_ease_from_point = _ease_from_point.lerp(_attach_point, _ease_t)
		_ease_t = 0.0
	_attach_point = found.point
	_normal = found.normal
	if climb > 0.0:
		# Still "at the top" if we only got this far because the height cap
		# clamped us there, even though the wall itself keeps going.
		_at_top = height_capped

func _let_go(p: Player, c: PlayerConfig) -> void:
	# A real push away from the wall, not just zero velocity — and the same
	# regrab cooldown jump_off_wall() uses — so Ground/Air's own
	# find_climbable_wall() check (still facing the same wall, barely any
	# distance covered yet) doesn't just grab it straight back next frame.
	p.velocity = -_normal * c.wall_release_push
	p.velocity.y = c.wall_drop_speed
	p.wall_climb_cd = Player.WALL_CLIMB_REGRAB_COOLDOWN
	machine.transition_to(&"Air")

func _jump(p: Player, c: PlayerConfig) -> void:
	if _at_top:
		# Nothing left to grab above — this reads as stepping off the top of
		# the wall, not kicking off of it: a normal straight-up jump instead
		# of jump_off_wall()'s horizontal push-away, held in the roll pose
		# for a beat, the same trick GroundState's steep-slope jump uses.
		p.can_dive = true
		p.wall_climb_cd = Player.WALL_CLIMB_REGRAB_COOLDOWN
		p.start_jump(c.jump_velocity)
		p.visual.play_hold(PlayerVisual.ANIM_ROLL, c.slope_jump_roll_hold_time)
	else:
		p.jump_off_wall(_normal)

func _apply_position(normal: Vector3, point: Vector3) -> void:
	player.global_position = point + normal * player.config.wall_hug_distance

## The player's screen/keyboard right while attached to a wall with this
## normal. While climbing, the player faces -normal (into the wall), and
## screen-right for someone facing `fwd` is fwd.cross(UP) — so right here is
## (-normal).cross(UP), i.e. UP.cross(normal).
func _wall_right(normal: Vector3) -> Vector3:
	var right := Vector3.UP.cross(normal)
	return right.normalized() if right.length() > 0.01 else Vector3.RIGHT
