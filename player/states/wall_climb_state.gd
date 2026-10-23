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
var _wall_body: Variant = null      ## that wall's own collider — excluded from the
									 ## obstruction check in _attempt_move() (see there and
									 ## Player.is_path_clear()), otherwise hugging its own
									 ## surface would constantly read as blocked by itself
var _at_top := false                ## true once climbing further up finds no more wall — makes
									 ## jump a plain vertical hop instead of a wall-jump kick-off

var _ease_from_normal := Vector3.FORWARD   ## corner-wrap/grab transitions blend FROM this pair...
var _ease_from_point := Vector3.ZERO
var _ease_t := 1.0                         ## ...TO _normal/_attach_point, over wall_wrap_time

## Same edge-crossing idiom GroundState's footsteps use (see its
## _update_footsteps): a sound fires each time the currently playing climb
## clip's own looping playback crosses one of CLIMB_SOUND_PHASES, instead of
## a fixed timer guessing at the cadence. _climb_sound_anim additionally
## tracks WHICH of the four directional clips that phase belongs to, since
## switching from one to another (e.g. climbing up into strafing right)
## mid-move restarts the cycle on a differently-timed clip.
const CLIMB_SOUND_PHASES := [0.0, 0.5]
var _climb_sound_anim := &""
var _climb_sound_phase := -1.0

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_normal = _msg.get("normal", Vector3.FORWARD)
	_attach_point = _msg.get("point", p.global_position)
	_wall_body = _msg.get("body", null)
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
	p.visual.play(PlayerVisual.ANIM_CLIMB_IDLE)

func physics_update(delta: float) -> void:
	var p := player
	var c := p.config

	# Full-strength A/D, same as ever — only WHICH of the two is "wall-right"
	# flips, based on which side of the wall the camera's currently looking
	# from (so A/D still mean screen-left/screen-right, like every other move
	# state, rather than a fixed keyboard direction regardless of camera
	# angle). Using input_dir() itself here instead would also project away
	# some of the input's magnitude whenever the camera isn't looking
	# squarely at the wall, quietly slowing the climb down — flipping just
	# the sign keeps full speed at any angle.
	var raw_strafe := Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left")
	var cam_yaw := p.camera_rig.yaw if p.camera_rig else 0.0
	var cam_right := Basis(Vector3.UP, cam_yaw) * Vector3.RIGHT
	# >= 0.0 rather than signf(), which returns 0.0 (not ±1.0) exactly square
	# to the wall — camera facing straight at or away from it, an entirely
	# normal angle to be climbing from, not an edge case to go unflipped for.
	var strafe := raw_strafe * (1.0 if cam_right.dot(_wall_right(_normal)) >= 0.0 else -1.0)
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
	var anim := _climb_anim(moving, strafe, climb)
	p.visual.play(anim)
	_update_climb_sound(p, moving, anim)

	if Input.is_action_pressed(&"crouch_pound"):
		_let_go(p, c)
		return
	if p.jump_buffer_t > 0.0:
		_jump(p, c)

## Tries to move `move * wall_climb_speed * delta` from the current attach
## point: clamped so it can't sink through the floor below, then checked
## against whatever's actually still climbable there (the same wall, a
## wrapped corner, or nothing — genuinely running out of wall is the only
## thing that counts as reaching the top; there's no height limit).
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

	# Position here is set directly rather than through move_and_slide()
	# (see this file's own doc comment), so nothing else stops a strafe/
	# climb move from sliding straight through solid world geometry that
	# isn't itself climbable — a perpendicular wall meeting this one at a
	# corner, a pillar, a ledge. Same "nothing found -> don't move" fallback
	# as running out of wall entirely.
	var tentative_body_pos := tentative + _normal * c.wall_hug_distance
	if not p.is_path_clear(p.global_position, tentative_body_pos, _wall_body):
		return

	# Checked wall_climb_head_clearance above `tentative`, not at the
	# player's own origin/feet height — _attach_point tracks the feet, but
	# stopping only once the FEET run out of wall left the head free to poke
	# out well above the top edge first (and, combined with the top-edge/
	# corner normal bug, let the player climb right onto the roof). Tune
	# the clearance in PlayerConfig if the stop point feels too low/high.
	var probe_point := tentative + Vector3.UP * c.wall_climb_head_clearance
	var found := p.probe_wall_near(probe_point, _normal, strafe)
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
	# found.point is at probe_point's (head) height, since probe_wall_near()
	# only sweeps horizontally — rebuild the stored attach point back at the
	# player's own origin height, keeping the wall-surface X/Z the probe
	# actually found (matters when this was a corner wrap).
	_attach_point = Vector3(found.point.x, tentative.y, found.point.z)
	_normal = found.normal
	_wall_body = found.get("body", null)
	if climb > 0.0:
		_at_top = false

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
		# for a beat (the same trick GroundState's steep-slope jump uses) but
		# purely cosmetically — blocks_control=false, so the player keeps
		# full air steering the instant they leave the wall, unlike the
		# slope-jump's deliberate brief "tumbling" control lock.
		p.can_dive = true
		p.wall_climb_cd = Player.WALL_CLIMB_REGRAB_COOLDOWN
		p.start_jump(c.jump_velocity)
		p.visual.play_hold(PlayerVisual.ANIM_ROLL, c.slope_jump_roll_hold_time, 1.0, false)
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

## The model has four distinct directional climb clips (up/down/left/right)
## instead of one blended loop, so a diagonal move just plays whichever axis
## is currently dominant rather than mixing two poses.
func _climb_anim(moving: bool, strafe: float, climb: float) -> StringName:
	if not moving:
		return PlayerVisual.ANIM_CLIMB_IDLE
	if absf(climb) >= absf(strafe):
		return PlayerVisual.ANIM_CLIMB_UP if climb > 0.0 else PlayerVisual.ANIM_CLIMB_DOWN
	return PlayerVisual.ANIM_CLIMB_RIGHT if strafe > 0.0 else PlayerVisual.ANIM_CLIMB_LEFT

## Same edge-crossing technique as GroundState's _update_footsteps, timed off
## whichever directional clip is currently playing instead of a fixed timer.
## Idle (not moving) plays nothing and resets the tracking, same as
## footsteps resetting while stopped/sliding — so the very next step after
## idle always starts a fresh cycle instead of picking up mid-stride.
func _update_climb_sound(p: Player, moving: bool, anim: StringName) -> void:
	if not moving:
		_climb_sound_anim = &""
		_climb_sound_phase = -1.0
		return
	if anim != _climb_sound_anim:
		# Switched which directional clip is playing (e.g. climbing up into
		# strafing right) — these aren't the same cycle, so restart tracking
		# rather than comparing a phase against a differently-timed clip.
		_climb_sound_anim = anim
		_climb_sound_phase = -1.0
	var phase := p.visual.anim_phase(anim)
	if phase < 0.0:
		_climb_sound_phase = -1.0
		return
	if _climb_sound_phase < 0.0:
		_climb_sound_phase = phase
		return
	var cur := phase
	if cur < _climb_sound_phase:
		cur += 1.0   # looped back around since the last frame
	for step in CLIMB_SOUND_PHASES:
		if (_climb_sound_phase <= step and step < cur) or (_climb_sound_phase <= step + 1.0 and step + 1.0 < cur):
			p.audio.play_climb()
	_climb_sound_phase = phase
