class_name Player
extends CharacterBody3D
## Platformer controller. Movement logic lives in states/; this class owns the
## shared physics helpers, timers and the stat/damage interface.

@export var config: PlayerConfig = PlayerConfig.new()

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const RADIUS := 0.4
const HIT_INVULN := 0.8
const SLIME_SPEED_MULT := 0.5   ## ground speed kept while standing in a slime puddle

## A wall is climbable purely by having this collision layer bit set (in
## addition to whatever else it's on, e.g. layer 1 for its solid collision)
## — no extra node needed, just a checkbox in the Inspector's Collision
## Layer grid per-wall. See find_climbable_wall()/probe_wall_near() and
## player/states/wall_climb_state.gd.
const CLIMBABLE_MASK := 1 << 8   # layer 9: climbable walls
const WALL_CLIMB_REGRAB_COOLDOWN := 0.3   ## see wall_climb_cd
## See swim_exit_cd. Long enough for a surface jump's own upward speed to
## actually clear the water before _update_water() starts checking
## submersion again — without this, jumping out near the surface
## transitioned to Air, but global_position hadn't moved yet that same
## frame, so the very next _update_water() call (still reading the same
## "deep enough" submersion) immediately transitioned straight back into
## Swim before the jump could ever actually leave the water.
const SWIM_EXIT_GRACE := 0.5

## Opt a StaticBody3D/other collider out of the stair-step-up assist (see
## _try_step_up()) by adding IT (not the player) to this group in the editor.
## Meant for short-but-narrow decorative props: the stepper can successfully
## climb onto something shorter than max_step_height, but if it's also
## narrower than the player's stride, the player immediately walks off the
## far edge, falls back to ground level right in front of it, and triggers
## the same step-up again next frame — a tight climb/fall-off loop that reads
## as "stuck jittering in place" rather than a clean bonk against a wall.
## Tag the prop's collider with this group to make it collide like an
## ordinary wall instead of a climbable step.
const NO_STEP_UP_GROUP := &"no_step_up"

## See the registration comment in _ready() and _unstick() below.
const UNSTICK_ACTION := &"debug_unstick"   ## bound to F9

## See _update_auto_unstick().
const AUTO_UNSTICK_TIME := 1.2      ## seconds of near-zero drift while airborne before it self-corrects
const AUTO_UNSTICK_EPSILON := 0.05  ## total movement below this over that window still counts as "not moving"

## Godot's automatic floor-snap re-grounds the body if it's within this
## distance of a floor after move_and_slide() — see _update_floor_snap().
const GROUND_FLOOR_SNAP := 0.3
const JUMP_FLOOR_SNAP := 0.0

var camera_rig: CameraRig
var visual: PlayerVisual
var effects: PlayerEffects
var audio: PlayerAudio
var xray: PlayerXray
var speed_trail: PlayerSpeedTrail
var ground_shadow: GroundShadow
var machine: StateMachine

var facing := Vector3.FORWARD
var can_dive := true
var dead := false
var coyote := 0.0
var jump_buffer_t := 0.0
var invuln := 0.0
var roll_cd := 0.0
var wall_climb_cd := 0.0   ## >0 right after jumping off a wall, so the same per-frame
						   ## find_climbable_wall() check can't instantly re-grab it
var swim_exit_cd := 0.0   ## >0 right after jumping out of the water, so _update_water()
						   ## can't instantly transition straight back into Swim — see SWIM_EXIT_GRACE

const LEAN_PITCH_MAX := 0.18     ## ~10 degrees, forward/back lean at full speed
const LEAN_BANK_MAX := 0.28      ## ~16 degrees, side bank at the fastest turns
const LEAN_TURN_SCALE := 0.12    ## how much yaw rate (rad/s) converts into bank (rad)
const LEAN_SMOOTH := 9.0         ## higher = snappier lean response

var _shape: CapsuleShape3D
var _shape_node: CollisionShape3D
var _wall_cast: ShapeCast3D   ## see find_climbable_wall()/probe_wall_near()
var _obstruction_cast: ShapeCast3D   ## see is_path_clear()
var _was_on_floor := true
var _last_safe_position: Vector3   ## most recent on_floor() position — see _unstick()
var _auto_stuck_pos: Vector3       ## see _update_auto_unstick()
var _auto_stuck_t := 0.0
var _air_t := 0.0   ## time since floor contact was last lost; gates the landing squash
var _prev_facing_yaw := 0.0
var _slime_overlaps := 0   ## count, not bool — several puddles can overlap at once
var _water_volumes: Array[WaterVolume] = []   ## every WaterVolume currently overlapping the player —
												## see enter_water()/exit_water()/current_water()

func _ready() -> void:
	collision_layer = 1 << 1   # layer 2: player
	collision_mask = 1 | (1 << 6)   # layer 1: world, layer 7: arena walls
	add_to_group(&"player")
	floor_snap_length = GROUND_FLOOR_SNAP
	floor_max_angle = deg_to_rad(50.0)
	# Godot's default (0.001) is tuned for ordinary geometry. Against a very
	# thin/near-degenerate static collider (a wall-thickness BoxShape3D with
	# one dimension close to zero, say) it isn't enough margin for
	# move_and_slide()'s depenetration step to reliably find a way back out,
	# and the body can stick dead in place on contact with no further motion.
	# A larger margin costs nothing visually (it's an invisible physics-only
	# buffer) and makes contact resolution robust against any thin collider
	# in the level, not just one specific wall.
	safe_margin = 0.04
	# Landing on TOP of a thin wall/ledge is one failure mode of the same
	# underlying problem: the capsule (0.8 diameter, see RADIUS) can easily be
	# wider than the ledge is thick, so it contacts the top face (floor
	# normal) and a side face (wall normal) in the same physics step. Jumping
	# UP into the edge of an overhang/roof is the mirrored case — the capsule's
	# top hits the underside (ceiling normal) and its side hits the roof's
	# edge (wall normal) at the same time. Either way it's two near-
	# perpendicular contacts resolved in one step, and the default max_slides
	# (4) can run out of iterations on that, collapsing velocity to ~zero and
	# wedging the body in the corner instead of sliding off it. A larger
	# safe_margin (above) plus extra slide iterations gives move_and_slide()
	# room to actually resolve both variants instead of freezing.
	max_slides = 10

	_shape = CapsuleShape3D.new()
	_shape.radius = RADIUS
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = _shape
	add_child(_shape_node)
	set_crouching(false)

	# A small sphere sweep rather than an infinitely thin ray — far more
	# forgiving of exactly where a climbable surface sits relative to the
	# probe (a grazing approach angle, a wall that's a hair off from where
	# the probe expected it, ...). `enabled = false` turns off its automatic
	# per-physics-frame update; find_climbable_wall()/probe_wall_near()
	# reposition and fire it manually (force_shapecast_update()) on demand.
	_wall_cast = ShapeCast3D.new()
	var wall_shape := SphereShape3D.new()
	wall_shape.radius = config.wall_probe_radius
	_wall_cast.shape = wall_shape
	_wall_cast.collision_mask = CLIMBABLE_MASK
	_wall_cast.add_exception(self)
	_wall_cast.enabled = false
	add_child(_wall_cast)

	# WallClimbState sets position directly rather than going through
	# move_and_slide() (see its own doc comment for why), so nothing normally
	# stops it sliding straight through solid world geometry other than
	# whichever climbable wall it's currently attached to — a perpendicular
	# wall meeting the climbed one at a corner, a pillar, a ledge, anything
	# that isn't itself climbable. is_path_clear() below is WallClimbState's
	# one check against that, reusing the same small-sphere-sweep idiom as
	# _wall_cast; a separate node since its mask/exceptions differ (world
	# geometry only, and the exception list changes per climb rather than
	# being fixed at startup).
	_obstruction_cast = ShapeCast3D.new()
	var obstruction_shape := SphereShape3D.new()
	obstruction_shape.radius = RADIUS * 0.6   ## smaller than the body itself — this only needs
												## to catch a real solid in the way, not every
												## graze against the climbed wall's own edge
	_obstruction_cast.shape = obstruction_shape
	_obstruction_cast.collision_mask = 1   # world geometry — not CLIMBABLE_MASK; that's handled separately
	_obstruction_cast.add_exception(self)
	_obstruction_cast.enabled = false
	add_child(_obstruction_cast)

	visual = PlayerVisual.new()
	add_child(visual)

	effects = PlayerEffects.new()
	add_child(effects)

	audio = PlayerAudio.new()
	add_child(audio)

	xray = PlayerXray.new()
	add_child(xray)
	xray.setup(self)

	speed_trail = PlayerSpeedTrail.new()
	add_child(speed_trail)
	speed_trail.setup(self)

	ground_shadow = GroundShadow.new()
	add_child(ground_shadow)
	ground_shadow.setup(self)

	machine = StateMachine.new()
	machine.name = "StateMachine"
	add_child(machine)
	machine.setup(self, {
		&"Ground": GroundState.new(), &"Crouch": CrouchState.new(),
		&"Roll": RollState.new(), &"Air": AirState.new(),
		&"LongJump": LongJumpState.new(), &"Dive": DiveState.new(),
		&"Pound": PoundState.new(), &"PoundLand": PoundLandState.new(),
		&"Frozen": FrozenState.new(), &"WallClimb": WallClimbState.new(),
		&"Swim": SwimState.new(),
	})
	machine.start(&"Ground")

	# A last-resort manual escape hatch: whatever gets a player wedged or
	# stuck (bad collision geometry, an accidental climbable surface like the
	# one removed from hometown.tscn, something not yet discovered), no
	# automatic detector can promise to catch every case without also
	# false-triggering on legitimate holds — WallClimbState, for instance, is
	# SUPPOSED to let you hang motionless on a wall, so "not moving while
	# airborne" can't just mean "stuck" on its own. A player-pressed key sidesteps
	# that entirely: it only ever fires when someone decides they're actually
	# stuck. Registered here in code (not project.godot) so it works without
	# any project-settings edit and can't merge-conflict with one; remap by
	# changing the keycode below or wiring UNSTICK_ACTION into the input map
	# properly later if it should be player-rebindable.
	if not InputMap.has_action(UNSTICK_ACTION):
		InputMap.add_action(UNSTICK_ACTION)
		var unstick_key := InputEventKey.new()
		unstick_key.physical_keycode = KEY_F9
		InputMap.action_add_event(UNSTICK_ACTION, unstick_key)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if Input.is_action_just_pressed(UNSTICK_ACTION):
		_unstick()
		return
	_update_timers(delta)
	_update_floor_snap()
	_update_water()
	machine.physics_update(delta)
	var on_floor := is_on_floor()
	if on_floor:
		_last_safe_position = global_position   ## see _unstick()
	_update_auto_unstick(delta, on_floor)
	if on_floor and not _was_on_floor:
		can_dive = true
		# Only squash for a real fall, not a split-second floor-contact flicker
		# (slopes/stairs/small bumps toggling is_on_floor() during plain walking).
		if _air_t >= config.min_air_time_for_land_squash:
			visual.squash_stretch(visual.land_squash_y, visual.land_squash_xz)
			effects.burst_land_dust()
		Events.player_landed.emit()
	_air_t = 0.0 if on_floor else _air_t + delta
	_was_on_floor = on_floor
	_update_lean(delta)

## Arcade-style motion lean: pitch forward with ground speed, bank into turns.
## Only during plain ground locomotion (Ground/Crouch) — every other state
## (dive/pound/long jump/roll) already has its own baked animation, and
## layering a lean on top of those would fight the authored pose.
func _update_lean(delta: float) -> void:
	var yaw := atan2(-facing.x, -facing.z)
	var yaw_rate := wrapf(yaw - _prev_facing_yaw, -PI, PI) / maxf(delta, 0.0001)
	_prev_facing_yaw = yaw

	var target_pitch := 0.0
	var target_bank := 0.0
	if machine.current_name == &"Ground" or machine.current_name == &"Crouch":
		var speed_ratio := clampf(get_hvel().length() / config.walk_speed, 0.0, 1.6)
		# Facing is -Z, so tipping the body's +Y axis toward -Z (lean forward,
		# into the movement) is a NEGATIVE rotation.x — positive would lean back.
		target_pitch = -speed_ratio * LEAN_PITCH_MAX
		# yaw increases when turning left (see face()/atan2 convention below), and
		# a positive rotation.z already tips the body toward -X (the character's
		# left), so banking into the turn means matching yaw_rate's sign directly.
		target_bank = clampf(yaw_rate * LEAN_TURN_SCALE, -LEAN_BANK_MAX, LEAN_BANK_MAX)

	visual.set_lean(target_pitch, target_bank, LEAN_SMOOTH, delta)

func _update_timers(delta: float) -> void:
	coyote = config.coyote_time if is_on_floor() else maxf(0.0, coyote - delta)
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_t = config.jump_buffer
	else:
		jump_buffer_t = maxf(0.0, jump_buffer_t - delta)
	invuln = maxf(0.0, invuln - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	wall_climb_cd = maxf(0.0, wall_climb_cd - delta)
	swim_exit_cd = maxf(0.0, swim_exit_cd - delta)

## Every jump/bounce/pound-jump sets velocity.y and switches state WITHOUT
## calling move_and_slide() that same frame — the new state's own
## physics_update does that a frame later. Up to that point the body hasn't
## actually moved, so it's still sitting exactly on the floor the instant
## that first move_and_slide() call happens — precisely the condition
## Godot's automatic floor-snap exists to catch, and it does: regardless of
## velocity.y's sign, it can silently re-ground the body on that very call,
## which looks like "the jump's effects/sound played but you never left the
## ground." Disabling the snap for as long as velocity.y is actually
## positive (rising) sidesteps this no matter which move set it, and the
## normal snap distance comes right back the instant gravity turns it
## negative — well clear of the floor by then, and still wanted for
## catching landings on slopes/stairs without a visible bump.
func _update_floor_snap() -> void:
	if machine.current_name == &"Swim":
		# Godot's own floor-snap/floor-slide behavior, not just the custom
		# _try_step_up() assist (already exempted below), was the other half
		# of "turning while swimming pushes you up": swimming close enough to
		# the lake bed to read as is_on_floor() left floor_snap_length at its
		# normal grounded value, so move_and_slide() kept treating the bed
		# like a floor to adhere/slide along — turning into a sloped patch of
		# it could lift the body following the slope, exactly like walking up
		# a ramp, even though SwimState moves the player by swimming, not
		# walking. Zeroing it here switches that off entirely while buoyant.
		floor_snap_length = 0.0
		return
	floor_snap_length = JUMP_FLOOR_SNAP if velocity.y > 0.0 else GROUND_FLOOR_SNAP

## Checked every physics frame, before the current state's own physics_update
## — deep enough water takes over movement outright (SwimState) regardless of
## what any other state was doing, the same way a climbable wall or a steep
## slope preempts normal movement elsewhere in this file. Shallower water
## (below config.water_swim_depth_ratio) is left entirely to whichever
## grounded state is already running — see GroundState._play_footstep() for
## the wet-footstep/puddle side of that, which needs no state change at all.
## Frozen (a cutscene) and WallClimb (deliberately holding a wall) are the
## only states this won't interrupt, same exemptions _update_auto_unstick() uses.
func _update_water() -> void:
	var deep := water_submersion() >= config.water_swim_depth_ratio
	var exempt := machine.current_name == &"Frozen" or machine.current_name == &"WallClimb"
	if exempt:
		return
	if deep and machine.current_name != &"Swim" and swim_exit_cd <= 0.0:
		machine.transition_to(&"Swim")
	elif not deep and machine.current_name == &"Swim":
		# Air's own on-floor check next frame settles whether this is a true
		# fall or you've actually surfaced onto solid ground — same reasoning
		# as _unstick() forcing Air rather than guessing Ground directly.
		machine.transition_to(&"Air")

# ---------------------------------------------------------------- input / motion

## Camera-relative movement intent on the XZ plane (length 0..1).
func input_dir() -> Vector3:
	var v := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var yaw := camera_rig.yaw if camera_rig else 0.0
	return Basis(Vector3.UP, yaw) * Vector3(v.x, 0.0, v.y)

func get_hvel() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)

func set_hvel(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z

## Every state calls this instead of the built-in move_and_slide() directly.
## A genuinely degenerate static collider (zero, not just thin, thickness —
## e.g. a BoxShape3D imported with one extent rounding to exactly 0) can hand
## the physics server an ill-defined contact normal, and that can poison
## `velocity` with NaN/Inf components. Once that happens every future frame's
## math (move_toward, normalized(), comparisons — NaN compares false against
## everything) stays NaN forever: the body stops moving AND every pose that's
## driven by velocity/speed freezes too, which reads exactly like "stuck, no
## animation change" even though gameplay logic is still running fine. This
## is a safety net, not a substitute for fixing the actual collider — see the
## comment on safe_margin above for the real fix.
func safe_move_and_slide() -> void:
	if not velocity.is_finite():
		push_warning("Player velocity went non-finite (%s) — likely a degenerate collision shape nearby. Resetting to zero." % velocity)
		velocity = Vector3.ZERO
	_try_step_up()
	var pos_before := global_position
	move_and_slide()
	if not velocity.is_finite():
		velocity = Vector3.ZERO
	_resolve_wedge(pos_before)

## A second, different safety net from the one above: a convex outside corner
## — e.g. a wall meeting a roof overhang's trim, especially if they're
## separate collision meshes with a seam between them — can hand
## move_and_slide() two (or more) contact normals that genuinely conflict,
## not just a lot of them. No amount of max_slides iteration finds a way out
## of that; the body can sit there indefinitely with real nonzero velocity
## but zero actual displacement, perfectly pinned. Unlike the NaN case this
## produces no bad numbers to detect directly, so instead: if we're airborne,
## clearly trying to move, and genuinely not going anywhere for a sustained
## moment, treat that itself as "wedged" and shove free along whatever
## surfaces are pressing on us. This is also a safety net, not a fix for the
## underlying seam/corner geometry — but unlike the step-up opt-out group,
## there's no way to pre-tag "this corner might wedge someone," so a generic
## recovery is the only approach that covers corners we don't know about yet.
const WEDGE_STUCK_TIME := 0.2    ## how long "not actually moving" must persist before it counts as wedged
const WEDGE_MIN_SPEED := 0.5     ## below this, standing still is normal, not a sign of being stuck
const WEDGE_MOVE_EPSILON := 0.02 ## actual displacement below this (despite nonzero velocity) counts as "stuck"
const WEDGE_NUDGE_SPEED := 4.0
var _wedge_t := 0.0

func _resolve_wedge(pos_before: Vector3) -> void:
	if is_on_floor() or velocity.length() < WEDGE_MIN_SPEED:
		_wedge_t = 0.0
		return
	if global_position.distance_to(pos_before) > WEDGE_MOVE_EPSILON:
		_wedge_t = 0.0
		return
	_wedge_t += get_physics_process_delta_time()
	if _wedge_t < WEDGE_STUCK_TIME:
		return
	_wedge_t = 0.0
	var escape := Vector3.ZERO
	for i in get_slide_collision_count():
		escape += get_slide_collision(i).get_normal()
	if escape.is_zero_approx():
		escape = Vector3.UP
	push_warning("Player wedged in a corner near %s — nudging free." % global_position)
	velocity = escape.normalized() * WEDGE_NUDGE_SPEED
	move_and_slide()

## Player-triggered recovery (see UNSTICK_ACTION's registration in _ready()):
## bail out of whatever state/predicament is holding the player — a climb
## grab, a wedge neither of the automatic recoveries above caught, anything
## else not yet discovered — and drop them back at the last position they
## were actually standing on solid ground. Forces Air rather than Ground
## directly: _last_safe_position was recorded while on_floor() was true, but
## teleporting doesn't guarantee it still reads as grounded the instant
## afterward (the floor could have moved, or safe_margin might not catch it
## same-frame) — Air's own landing check settles that correctly next frame
## either way, same as any other fall.
func _unstick() -> void:
	push_warning("Player manually unstuck — returning to last safe ground position %s." % _last_safe_position)
	machine.transition_to(&"Air")
	global_position = _last_safe_position
	velocity = Vector3.ZERO
	_wedge_t = 0.0

## The automatic counterpart to _unstick() — same recovery, triggered by
## actually being stuck rather than a key press. Skips three states on
## purpose, all of which are SUPPOSED to leave the player motionless off
## the ground for as long as they like, not bugs to correct:
## - WallClimb: hanging still on a wall without pressing anything is normal.
## - Frozen: a scripted cinematic hold with gravity off; a cutscene can run
##   as long as it wants.
## - Swim: treading water (or just holding depth with no input) is normal
##   too — buoyant, not falling, however long it sits still.
## Every other state's own holds (wall-bounce reaction, pound windup, the
## various jump-pose locks — see PlayerConfig's *_hold_time/*_windup fields)
## top out well under a second, so "airborne, not meaningfully moving, for
## over AUTO_UNSTICK_TIME" has no legitimate reason to happen anywhere else
## and is a safe signal something's gone wrong, without needing to know what.
func _update_auto_unstick(delta: float, on_floor: bool) -> void:
	# Swim is deliberately motionless off the floor too — treading water in
	# place (or just holding depth with no input at all) is normal there,
	# same exemption reasoning as WallClimb/Frozen below, not a sign of
	# being stuck.
	var exempt := machine.current_name == &"WallClimb" or machine.current_name == &"Frozen" \
			or machine.current_name == &"Swim"
	if on_floor or exempt:
		_auto_stuck_t = 0.0
		_auto_stuck_pos = global_position
		return
	if global_position.distance_to(_auto_stuck_pos) > AUTO_UNSTICK_EPSILON:
		_auto_stuck_t = 0.0
		_auto_stuck_pos = global_position
		return
	_auto_stuck_t += delta
	if _auto_stuck_t >= AUTO_UNSTICK_TIME:
		_auto_stuck_t = 0.0
		_unstick()

## Stepped stairs are a series of small vertical risers, and a riser is just
## a wall as far as move_and_slide() is concerned — without this, climbing a
## staircase would mean bonking into every single step instead of walking up
## them, unless you also jumped at exactly the right moments. This runs
## right before the real move_and_slide() each physics frame and, if this
## frame's horizontal motion would be blocked by something no taller than
## config.max_step_height, teleports the body up onto it first — standard
## "stair-stepper" technique for a CharacterBody3D (Godot has no automatic
## step-offset like some other engines' character controllers):
##
## 1. Would the intended horizontal motion actually be blocked at the
##    current height? If not, there's no step to climb — bail immediately so
##    flat ground is never touched by this at all.
## 2. Is the same motion clear once raised by max_step_height? If it's STILL
##    blocked, whatever's ahead is taller than a climbable step (a real wall,
##    or too-tall a ledge) — bail and let the ordinary wall collision happen.
## 3. Settle back down from there onto whatever's actually underneath, so the
##    body's HEIGHT ends up resting on the stair's tread instead of floating
##    at a fixed height above the old floor — only the vertical correction is
##    committed here, never the horizontal advance; see the comment at the
##    bottom of this function for why. Checked against floor_max_angle too,
##    so this can't snap the body onto a steep surface or a low overhang edge
##    that merely happened to be within step range.
##
## Only runs while already grounded and actually moving horizontally — never
## kicks in mid-air, so it doesn't interfere with jump arcs or falling.
##
## Whatever's actually blocking ground-level motion gets one more check before
## any of the above: if it's tagged NO_STEP_UP_GROUP, bail immediately and let
## it collide like an ordinary wall — see that constant's comment for why.
func _try_step_up() -> void:
	# Swimming can graze the lake floor (near the shore, or just diving deep
	# enough) and briefly read as is_on_floor() too — this assist is only
	# meant for walking up literal stairs/curbs, and treating the floor
	# ahead as a climbable riser while buoyant launched the player straight
	# up out of the water on nothing more than turning toward it.
	if not is_on_floor() or machine.current_name == &"Swim":
		return
	var horizontal := velocity * Vector3(1.0, 0.0, 1.0)
	if horizontal.length() < 0.01:
		return

	# Probed config.step_probe_reach ahead — a FIXED distance, not however far
	# this exact frame's velocity happens to cover. Using the real per-frame
	# motion (as this used to) meant a slow approach could take a frame or two
	# to actually close the gap enough to register as "blocked" at all, and
	# until it did the capsule just collided with the riser's edge like a
	# plain wall — a visible stumble/slide right where a step should have
	# caught cleanly, and inconsistent frame to frame since it depended on
	# exactly how fast you happened to be moving at that exact distance from
	# the step. Only the Y correction below is ever committed either way (see
	# that comment), so the probe's own horizontal distance just needs to
	# clear the step's lip onto its tread for the settle check — it was never
	# tied to how far the player should actually move this frame.
	var dir := horizontal.normalized()
	var motion := dir * maxf(horizontal.length() * get_physics_process_delta_time(), config.step_probe_reach)
	var step := config.max_step_height

	var blocked := KinematicCollision3D.new()
	if not test_move(global_transform, motion, blocked):
		return   # nothing in the way at ground level — no step needed
	var collider := blocked.get_collider()
	if collider and collider.is_in_group(NO_STEP_UP_GROUP):
		return   # explicitly opted out — treat as a plain wall, don't attempt to climb it

	var raised := global_transform.translated(Vector3.UP * step)
	if test_move(raised, motion):
		return   # still blocked even raised this high — too tall a riser, or just a wall

	var advanced := raised.translated(motion)
	var settle := KinematicCollision3D.new()
	if not test_move(advanced, Vector3.DOWN * step, settle):
		return   # nothing solid within range right below — don't commit to a blind step
	if settle.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return   # not walkable floor (e.g. the underside of a low ledge) — don't snap onto it

	# Only the Y correction gets committed here — raise the body to the height
	# this frame's horizontal motion will actually clear the step at, and leave
	# X/Z exactly where they already are. `advanced` (this height PLUS motion)
	# was only ever needed to test whether the far side is walkable, not as a
	# position to commit outright: committing its horizontal part too (as this
	# used to) meant the real move_and_slide() call right after this function
	# returns then applied that SAME frame's velocity-driven horizontal motion
	# a second time, from the already-advanced spot — silently doubling how far
	# every step moved you. And "step" here isn't only literal stairs: a probe
	# this purely horizontal reads ANY continuous upward incline as a blocked
	# riser too (gravity doesn't stop the sweep from clipping the rising ground
	# ahead), so this doubling fired, and compounded every single physics
	# frame, on ordinary smooth ramps as well — faster movement (e.g. rolling)
	# hits it far more often than walking, since a bigger per-frame motion is
	# more likely to actually clip the slope ahead. Letting move_and_slide()
	# own the horizontal half fixes both cases at once without this function
	# needing to know or care which one it's looking at.
	global_position.y = (advanced.origin + settle.get_travel()).y

func apply_gravity(delta: float, mult := 1.0) -> void:
	var g := config.gravity * mult
	if velocity.y < 0.0:
		g *= config.fall_gravity_mult
	velocity.y = maxf(velocity.y - g * delta, -config.terminal_velocity)

## Rotate the model towards `dir`. Pass delta < 0 to snap.
func face(dir: Vector3, delta := -1.0) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	facing = dir.normalized()
	var target := atan2(-facing.x, -facing.z)
	visual.rotation.y = target if delta < 0.0 else lerp_angle(visual.rotation.y, target, minf(1.0, config.turn_speed * delta))

## Air steering that preserves momentum from rolls/dives/long jumps.
func air_control(delta: float) -> void:
	var input := input_dir()
	var h := get_hvel()
	var spd := h.length()
	if spd > config.air_speed + 0.5:
		if input.length() > 0.1:
			var ang := h.signed_angle_to(input, Vector3.UP)
			var lim := config.air_steer_rate * delta
			h = h.rotated(Vector3.UP, clampf(ang, -lim, lim))
		spd = maxf(config.air_speed, spd - config.momentum_drag * delta)
		h = h.normalized() * spd
	else:
		h = h.move_toward(input * config.air_speed, config.air_accel * delta)
	set_hvel(h)

## Magnitudes tried outward from 0° in probe_wall_near()'s corner-wrap
## search, each tried on whichever side the caller's `bias_sign` says the
## player is actually steering toward before the opposite side — see
## _wall_wrap_angles().
const WALL_WRAP_MAGNITUDES_DEG: Array[float] = [30.0, 60.0, 90.0, 120.0]

## Builds probe_wall_near()'s angle search order: 0° first (stay on the
## same flat wall), then each magnitude in WALL_WRAP_MAGNITUDES_DEG on the
## `bias_sign` side before its mirror on the other side. Without this bias
## the search order was a fixed left-before-right regardless of which way
## the player was actually steering, so a corner could just as easily wrap
## onto a wall behind/opposite their intended direction if it happened to
## resolve first — this makes it prefer whatever side the player is
## actually trying to go, falling back to the other side only if nothing
## climbable is there.
func _wall_wrap_angles(bias_sign: float) -> Array[float]:
	var s := signf(bias_sign) if absf(bias_sign) > 0.001 else 1.0
	var angles: Array[float] = [0.0]
	for mag in WALL_WRAP_MAGNITUDES_DEG:
		angles.append(mag * s)
		angles.append(-mag * s)
	return angles

## Sweeps a small sphere looking for a climbable surface at/around `point`,
## trying `old_normal` first and then that direction rotated by increasing
## angles around world UP (see _wall_wrap_angles(); `bias_sign` should be
## the player's current steering direction along the wall, positive or
## negative — WallClimbState passes its own `strafe`). This single search
## does double duty: with no rotation it's just "stay stuck to the wall I'm
## already on", and with a rotation it's "wrap onto whatever adjacent
## climbable wall is here instead, preferring the side I'm steering
## toward" — WallClimbState doesn't need to special-case corners at all,
## since both cases are just this same call finding a hit, possibly with a
## new normal.
func probe_wall_near(point: Vector3, old_normal: Vector3, bias_sign := 1.0) -> Dictionary:
	for angle_deg in _wall_wrap_angles(bias_sign):
		var dir := old_normal.rotated(Vector3.UP, deg_to_rad(angle_deg))
		var from := point + dir * config.wall_probe_reach
		_wall_cast.global_position = from
		_wall_cast.target_position = -dir * (config.wall_probe_reach + 0.1)
		_wall_cast.force_shapecast_update()
		if not _wall_cast.is_colliding():
			continue
		var normal: Vector3 = _wall_cast.get_collision_normal(0)
		if not _is_wall_normal(normal):
			continue
		normal.y = 0.0
		var hit_point: Vector3 = _wall_cast.get_collision_point(0)
		if not _wall_wide_enough(hit_point, -dir, config.wall_probe_reach):
			continue
		return {"point": hit_point, "normal": normal.normalized(),
				"body": _wall_cast.get_collider(0)}
	return {}

## True if a climbable surface is still there `wall_min_width * 0.5` to
## EITHER side of `point` along the wall's own tangent (perpendicular to
## `probe_dir`, the direction a probe just swept IN TO reach the wall at
## `point`) — see wall_min_width's own doc comment in PlayerConfig for why
## this check exists at all. Reuses _wall_cast (whatever hit it already
## recorded for the real grab/wrap has already been read out by the caller
## by the time this runs, so overwriting its state here is safe).
func _wall_wide_enough(point: Vector3, probe_dir: Vector3, reach: float) -> bool:
	var tangent := Vector3(-probe_dir.z, 0.0, probe_dir.x)
	var half := config.wall_min_width * 0.5
	for s in [1.0, -1.0]:
		_wall_cast.global_position = point - probe_dir * reach + tangent * s * half
		_wall_cast.target_position = probe_dir * (reach + 0.1)
		_wall_cast.force_shapecast_update()
		if not _wall_cast.is_colliding():
			return false
	return true

## True for a normal that's actually a wall's, not a floor, ceiling, or a
## wall's own top/bottom edge. Checked on the RAW normal, before zeroing its
## Y component to flatten it: a sphere sweep catching a box's top edge/corner
## returns a normal blended between the vertical face and the flat top, and
## that blend can easily keep more than the near-zero horizontal sliver a
## check on the already-flattened normal would catch — e.g. a corner hit
## could read as (0.3, 0.9, 0.3), which flattens to a "valid-looking"
## (0.3, 0, 0.3) even though it's really the top edge, not the wall's face.
## Rejecting anything more than ~45° off horizontal here, before that
## flattening throws the vertical component away, is what stops a climb
## from walking straight up and over onto a wall's flat roof instead of
## stopping at its actual top.
func _is_wall_normal(normal: Vector3) -> bool:
	return absf(normal.y) < 0.7

## True if a small sphere could move in a straight line from `from` to `to`
## without hitting solid world geometry (layer 1) — WallClimbState's check
## against sliding straight through anything solid that isn't the wall it's
## currently attached to (see its own doc comment and _obstruction_cast's).
## `ignore_body` is that currently-climbed wall's own collider: its solid
## collision shares layer 1 with everything else, so without excluding it
## specifically, hugging close to its surface would constantly read as
## blocked by the very wall being climbed.
##
## A hit on ANOTHER climbable wall doesn't count as blocked either: at an
## inside (concave) corner, moving tangentially along the current wall runs
## straight into the adjacent wall's own solid collision before
## probe_wall_near() ever gets a chance to discover and wrap onto it — since
## that's exactly what WallClimbState's corner-wrap is supposed to do, not
## something it should be stopped from reaching, only a hit on something
## that ISN'T climbable (a pillar, a prop, a genuine dead end) is treated as
## a real obstruction.
func is_path_clear(from: Vector3, to: Vector3, ignore_body: Variant) -> bool:
	if ignore_body is CollisionObject3D:
		_obstruction_cast.add_exception(ignore_body)
	_obstruction_cast.global_position = from
	_obstruction_cast.target_position = to - from
	_obstruction_cast.force_shapecast_update()
	var blocked := _obstruction_cast.is_colliding()
	if blocked:
		var collider := _obstruction_cast.get_collider(0)
		if collider is CollisionObject3D and (collider.collision_layer & CLIMBABLE_MASK) != 0:
			blocked = false
	if ignore_body is CollisionObject3D:
		_obstruction_cast.remove_exception(ignore_body)
	return not blocked

## Ground height straight down from `from`, within `max_dist` — same
## world-geometry layer (1) Arena.ground_height() probes, used by
## WallClimbState to stop climbing down from pushing the player through the
## floor at the base of a wall. Null if nothing's found in range.
func ground_height_below(from: Vector3, max_dist: float) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * max_dist, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else null

## Same probe as ground_height_below(), but returns the collider node itself
## instead of the hit height — used by GroundState to work out which
## footstep sound set to play (see FootstepSurfaces.detect()). Null if
## nothing's found in range.
##
## Unlike ground_height_below(), this also hits Area3Ds (collide_with_areas)
## on the same world layer — a surface that's visually there but whose real
## collision is deliberately off (e.g. a decorative flat rock path mesh that
## just rides on the terrain collider underneath it) can still be given a
## marker Area3D of its own, purely so footsteps can detect it; since an
## Area3D never affects movement, it's safe to add without changing how the
## ground itself actually collides. Give the marker a shape matching the
## mesh's footprint, collision_layer = 1 (world), and either name it so
## FootstepSurfaces' keyword guess picks it up or put it straight in a
## "surface_<name>" group for an explicit override — see that file.
func floor_collider_below(from: Vector3, max_dist: float) -> Node:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * max_dist, 1)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() else null

## Looks for a climbable wall directly ahead — called from Ground/Air/Dive/
## LongJump every frame to auto-grab on touch or on landing into one, same
## spirit as the old ledge/pole triggers but done with a probe instead of an
## Area3D, since "climbable" here is just a collision layer bit on the
## wall's own existing body, not a dedicated node.
##
## wall_climb_cd normally blocks this right after jumping off a wall, so the
## kick-off's own push doesn't just re-stick you to the same wall before
## you've actually moved away from it — that's an incidental, unintended
## re-grab, not something the player asked for. ignore_cooldown lets a
## deliberate action skip that block: DiveState passes it so launching off a
## wall and immediately diving back into it climbs again right away, instead
## of being treated as the very re-grab the cooldown exists to prevent.
func find_climbable_wall(ignore_cooldown := false) -> Dictionary:
	if wall_climb_cd > 0.0 and not ignore_cooldown:
		return {}
	# `facing`, not `-facing`: when hvel is too small to tell (standing still,
	# or just bumped a wall head-on and move_and_slide() zeroed the velocity),
	# probe the direction the player is actually looking, not behind them —
	# using -facing here was grabbing walls the player had their back to.
	var dir := get_hvel()
	dir = dir if dir.length() > 0.1 else facing
	dir = Vector3(dir.x, 0.0, dir.z)
	if dir.length() < 0.001:
		return {}
	dir = dir.normalized()
	var probe_origin := global_position + Vector3.UP * (STAND_HEIGHT * 0.5)
	var reach := RADIUS + config.wall_grab_reach
	_wall_cast.global_position = probe_origin
	_wall_cast.target_position = dir * reach
	_wall_cast.force_shapecast_update()
	if not _wall_cast.is_colliding():
		return {}
	var normal: Vector3 = _wall_cast.get_collision_normal(0)
	if not _is_wall_normal(normal):
		return {}
	normal.y = 0.0
	var raw_point: Vector3 = _wall_cast.get_collision_point(0)
	if not _wall_wide_enough(raw_point, dir, reach):
		return {}
	# The probe sweeps at chest height (probe_origin above), but global_position
	# itself is the player's feet — returning the hit point as-is would plant
	# the player's feet at chest height once WallClimbState applies it
	# (point + normal * hug_distance becomes the new global_position),
	# visibly popping them up by STAND_HEIGHT * 0.5 on every grab. Undo that
	# offset here so the returned point lines up with the player's own origin
	# height instead of the probe's.
	var point := raw_point
	point.y -= STAND_HEIGHT * 0.5
	return {"point": point, "normal": normal.normalized(), "body": _wall_cast.get_collider(0)}

# ---------------------------------------------------------------- actions

## Every jump is a fixed, snappy height — no variable height from holding the
## button, so the timing always feels the same regardless of how long jump is held.
## `pound` plays the dedicated ground_pound_jump.wav instead of the plain
## jump.wav — PoundLandState's high-jump-out-of-recovery combo is the only
## caller that passes it.
func start_jump(vel: float, pound := false) -> void:
	if is_slimed():
		# Still consume the buffered jump so a held/mashed jump input doesn't
		# keep re-triggering this no-op every frame — each caller returns
		# immediately after calling start_jump(), assuming a jump happened,
		# so leaving jump_buffer_t set would stall ground movement each of
		# those frames until the buffer window expired on its own.
		jump_buffer_t = 0.0
		print("[JumpDebug] start_jump() suppressed: standing in slime")
		return
	velocity.y = vel
	coyote = 0.0
	jump_buffer_t = 0.0
	# Unlike start_side_flip() below (which calls play_hold() itself, forcing
	# its own pose in immediately), this jump's pose only ever gets played by
	# AirState's regular per-frame play() call next frame — which silently
	# refuses to play anything while an earlier hold (a side flip's pose,
	# say) is still protected. Without this, jumping again shortly after a
	# side flip (or any other held pose) could look like the jump did
	# nothing at all, even though it physically happened.
	visual.cancel_hold()
	visual.squash_stretch(visual.jump_stretch_y, visual.jump_stretch_xz)
	visual.roll_jump_start()
	effects.burst_jump_dust()
	audio.play_pound_jump() if pound else audio.play_jump()
	machine.transition_to(&"Air")

## Mario 64-style skid-turn trick: jumping while skidding from a sharp
## direction reversal (see GroundState's slide/_slide_is_turn) launches a
## higher-arcing side flip toward `dir` instead of a plain vertical jump.
func start_side_flip(dir: Vector3) -> void:
	if is_slimed():
		jump_buffer_t = 0.0   # see start_jump()'s identical guard for why
		return
	set_hvel(dir.normalized() * config.side_flip_speed)
	velocity.y = config.side_flip_jump_velocity
	face(dir)
	coyote = 0.0
	jump_buffer_t = 0.0
	can_dive = true
	# side_jump's keyframes come out of the model reversed — played
	# back-to-front (speed -1) instead of literally reversing it.
	visual.play_hold(PlayerVisual.ANIM_SIDE_JUMP, config.side_flip_hold_time, -1.0)
	effects.burst_jump_dust()
	audio.play_side_flip()
	machine.transition_to(&"Air")

## Called whenever find_climbable_wall() finds one, from any state. Guarded
## against Frozen (a cutscene shouldn't be interrupted by scenery), against
## re-entering WallClimb while already climbing, and against the brief
## regrab cooldown right after jumping off one.
## ignore_cooldown mirrors find_climbable_wall()'s own param (see there) —
## DiveState finds the wall AND grabs it with the cooldown ignored, so a
## dive straight back into a wall you just jumped off of climbs immediately
## instead of silently failing to transition here for the rest of the
## cooldown while find_climbable_wall() keeps finding it every frame.
func grab_wall(point: Vector3, normal: Vector3, body: Variant = null, ignore_cooldown := false) -> void:
	if dead or machine.current_name == &"Frozen" or machine.current_name == &"WallClimb":
		return
	if wall_climb_cd > 0.0 and not ignore_cooldown:
		return
	machine.transition_to(&"WallClimb", {"point": point, "normal": normal, "body": body})

## Launches away from whatever wall you were climbing, toward `away`, with
## its own distinct push/height (independent of start_jump()'s
## jump_velocity). Arms wall_climb_cd so the very next frame's
## find_climbable_wall() (which would otherwise still be facing the same
## wall) can't instantly re-grab it.
func jump_off_wall(away: Vector3) -> void:
	set_hvel(away * config.wall_jump_off_speed)
	velocity.y = config.wall_jump_off_velocity
	face(away)
	coyote = 0.0
	jump_buffer_t = 0.0
	can_dive = true
	wall_climb_cd = WALL_CLIMB_REGRAB_COOLDOWN
	visual.cancel_hold()
	visual.squash_stretch(visual.jump_stretch_y, visual.jump_stretch_xz)
	visual.roll_jump_start()
	effects.burst_jump_dust()
	audio.play_jump()
	machine.transition_to(&"Air")

## `combo` is Arena's running combo count for this hit (1 on the first orb of
## a chain) — forwarded to the attack sound so it climbs with the combo
## instead of playing identically on every hit. Defaults to 1 for any other
## caller that doesn't track a combo.
func bounce_off_orb(combo := 1) -> void:
	set_hvel(Vector3.ZERO)   # a clean vertical pop, even out of a fast dive
	velocity.y = config.orb_bounce_velocity
	can_dive = true
	# Hold the attack pose for roughly as long as the bounce takes to reach its
	# apex, not a flat duration — so the falling pose never pops in mid-rise.
	var rise_time := config.orb_bounce_velocity / config.gravity
	visual.play_random_attack(rise_time * config.orb_attack_hold_mult)
	audio.play_orb_attack(combo)
	machine.transition_to(&"Air")

## Call after move_and_slide() from Dive / LongJump / Roll with the pre-move
## horizontal velocity. Always launches into Air with an upward pop — this is
## the one bounce mechanic shared by every state that can hit a wall hard
## enough; `bounce_anim`/`bounce_time` just let each caller pick its own
## reaction pose (a looping tumble for the airborne ones, a sharper collision
## pose for rolling into one on the ground).
## Each source bounces once: a long-jump bounce re-grants the dive (so a dive can
## bounce too), a dive bounce does not, so the chain ends there until you land.
## `allow_grounded` lets Roll (which is still on the floor the instant this is
## called) trigger it too — everyone else is already airborne so it's moot.
## `vertical_only` swaps the usual cannon-off-the-wall push for a plain
## straight-up pop instead — the same read as stepping off the top of a
## climbed wall (see WallClimbState._jump()'s _at_top case: a normal
## start_jump(), no horizontal kick). Dive uses this: diving straight at a
## wall shouldn't fling you back the way you came, it should just carry you
## up it, so the lunge still makes forward progress instead of undoing itself.
func try_wall_bounce(prev_hvel: Vector3, regrants_dive: bool, bounce_anim: StringName,
		bounce_time: float, allow_grounded := false, vertical_only := false) -> bool:
	if (is_on_floor() and not allow_grounded) or not is_on_wall() or prev_hvel.length() < config.wall_min_speed:
		return false
	var n := get_wall_normal()
	n.y = 0.0
	if n.length() < 0.1:
		return false
	n = n.normalized()
	if (-prev_hvel.normalized()).dot(n) < 0.35:
		return false
	if vertical_only:
		velocity = Vector3.ZERO
		velocity.y = config.jump_velocity
	else:
		velocity = n * config.wall_bounce_push
		velocity.y = config.wall_bounce_up
	face(n)
	# blocks_control=false for the vertical-only case, same reasoning as
	# WallClimbState._jump()'s _at_top hold: the pose is purely cosmetic here,
	# not a reaction you're meant to ride out — AirState's own air_control()
	# check (is_holding_control()) lets steering through immediately instead
	# of waiting the full bounce_time out, so the dive still feels responsive
	# on the way up rather than momentarily taking control away from you.
	visual.play_hold(bounce_anim, bounce_time, 1.0, not vertical_only, 0.0)   # instant cut — see play_hold()'s blend doc
	var impact_pos := global_position + n * RADIUS + Vector3.UP * (STAND_HEIGHT * 0.5)
	if bounce_anim == PlayerVisual.ANIM_ROLL_COLLISION:
		effects.burst_roll_collision(impact_pos, n)
		audio.play_roll_bounce()
	else:
		effects.burst_wall_impact(impact_pos, n)
		audio.play_wall_bounce()
	if regrants_dive:
		can_dive = true
	# Same hygiene as start_jump(): a wall bounce counts as a jump, so make sure
	# a leftover buffered jump / coyote window can't immediately re-fire a second,
	# different jump on top of it the moment AirState ticks next frame. But a
	# jump pressed on this exact same frame is left alone instead of wiped —
	# Dive/LongJump check this every frame unconditionally (unlike Roll, which
	# checks jump first and returns before it can reach this call), so a jump
	# press that happens to land on the same frame as a wall bounce (clipping
	# a wall mid-dive/long-jump, say) was getting silently eaten here instead
	# of carrying through to the landing it was actually meant for. coyote is
	# still zeroed below, so AirState's own coyote gate already blocks it from
	# immediately re-firing on top of the bounce — it only takes effect once
	# the player genuinely lands within the buffer's own short window.
	coyote = 0.0
	if jump_buffer_t < config.jump_buffer:
		jump_buffer_t = 0.0
	machine.transition_to(&"Air")
	return true

## Collision only — shrinks the capsule to CROUCH_HEIGHT. Several states use
## the smaller capsule for reasons that have nothing to do with the crouch
## pose (Roll wants to duck under things while rolling, for instance), so the
## visual squash is a separate, explicit call (visual.set_crouch) that only
## CrouchState makes, rather than something this always drags along with it.
func set_crouching(c: bool) -> void:
	var h := CROUCH_HEIGHT if c else STAND_HEIGHT
	_shape.height = h
	_shape_node.position.y = h * 0.5

func can_stand() -> bool:
	return not test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT))

## Hold the player in place (state does nothing); the caller moves them by script.
func enter_cinematic() -> void:
	machine.transition_to(&"Frozen")

func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	dead = false
	set_crouching(false)
	machine.transition_to(&"Ground")

# ---------------------------------------------------------------- slime puddles

## Called by SlimePuddle while the player is standing in it. A counter, not a
## flag, since overlapping puddles must not cancel each other's effect out
## the moment just one of them is left. `color` is that specific puddle's own
## color (SlimePuddle.color, which varies per enemy — see EnemyData's slime
## trail accent) so the drip particles always match whatever puddle you're
## actually standing in, even stepping straight from one color into another.
func enter_slime_puddle(color := PlayerVisual.SLIME_TINT_COLOR) -> void:
	_slime_overlaps += 1
	visual.set_slimed(true)
	effects.set_slime_drip(true, color)

func exit_slime_puddle() -> void:
	_slime_overlaps = maxi(0, _slime_overlaps - 1)
	if _slime_overlaps == 0:
		visual.set_slimed(false)
		effects.set_slime_drip(false)

func is_slimed() -> bool:
	return _slime_overlaps > 0

# ---------------------------------------------------------------- water

## Called by WaterVolume while the player's body overlaps it. An array
## (rather than slime's plain counter) since the submersion depth below
## depends on WHICH volume — current_water() needs an actual reference, not
## just a count — but overlapping more than one at once is rare enough that
## "whichever was entered most recently" (the array's own back()) is a fine
## answer when it does happen.
func enter_water(vol: WaterVolume) -> void:
	if vol not in _water_volumes:
		_water_volumes.append(vol)

func exit_water(vol: WaterVolume) -> void:
	_water_volumes.erase(vol)

func current_water() -> WaterVolume:
	return _water_volumes.back() if not _water_volumes.is_empty() else null

## 0.0 (dry) to 1.0 (fully underwater) — see WaterVolume.submersion_ratio().
func water_submersion() -> float:
	var vol := current_water()
	return vol.submersion_ratio(global_position.y, STAND_HEIGHT) if vol else 0.0

# ---------------------------------------------------------------- damage

func hit(amount: float, pierces_shield := false) -> void:
	if dead or invuln > 0.0 or Game.god_mode:
		return
	invuln = HIT_INVULN
	visual.flash()
	var hp_before := Game.stats.hp
	var died := Game.stats.take_damage(amount, pierces_shield)
	# Only the "hurt" face, not flash() above — that stays on every hit
	# regardless of shield, same as before. A hit fully absorbed by shield
	# (hp unchanged) shouldn't show a pain reaction; checking the actual
	# before/after hp here is more robust than just branching on
	# pierces_shield, since a non-piercing hit can still dip into hp once
	# shield runs out, and that should show hurt too.
	if Game.stats.hp < hp_before:
		visual.show_hurt()
	if died:
		dead = true
		velocity = Vector3.ZERO
		Events.player_died.emit()
