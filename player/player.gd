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

## Godot's automatic floor-snap re-grounds the body if it's within this
## distance of a floor after move_and_slide() — see _update_floor_snap().
const GROUND_FLOOR_SNAP := 0.3
const JUMP_FLOOR_SNAP := 0.0

var camera_rig: CameraRig
var visual: PlayerVisual
var effects: PlayerEffects
var audio: PlayerAudio
var xray: PlayerXray
var ground_shadow: GroundShadow
var machine: StateMachine

var facing := Vector3.FORWARD
var can_dive := true
var dead := false
var coyote := 0.0
var jump_buffer_t := 0.0
var invuln := 0.0
var roll_cd := 0.0

const LEAN_PITCH_MAX := 0.18     ## ~10 degrees, forward/back lean at full speed
const LEAN_BANK_MAX := 0.28      ## ~16 degrees, side bank at the fastest turns
const LEAN_TURN_SCALE := 0.12    ## how much yaw rate (rad/s) converts into bank (rad)
const LEAN_SMOOTH := 9.0         ## higher = snappier lean response

var _shape: CapsuleShape3D
var _shape_node: CollisionShape3D
var _was_on_floor := true
var _air_t := 0.0   ## time since floor contact was last lost; gates the landing squash
var _prev_facing_yaw := 0.0
var _slime_overlaps := 0   ## count, not bool — several puddles can overlap at once

func _ready() -> void:
	collision_layer = 1 << 1   # layer 2: player
	collision_mask = 1 | (1 << 6)   # layer 1: world, layer 7: arena walls
	add_to_group(&"player")
	floor_snap_length = GROUND_FLOOR_SNAP
	floor_max_angle = deg_to_rad(50.0)

	_shape = CapsuleShape3D.new()
	_shape.radius = RADIUS
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = _shape
	add_child(_shape_node)
	set_crouching(false)

	visual = PlayerVisual.new()
	add_child(visual)

	effects = PlayerEffects.new()
	add_child(effects)

	audio = PlayerAudio.new()
	add_child(audio)

	xray = PlayerXray.new()
	add_child(xray)
	xray.setup(self)

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
		&"Frozen": FrozenState.new(), &"LedgeHang": LedgeHangState.new(),
	})
	machine.start(&"Ground")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_timers(delta)
	_update_floor_snap()
	machine.physics_update(delta)
	var on_floor := is_on_floor()
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
		print("[JumpDebug] jump pressed | state=%s on_floor=%s coyote=%.3f slimed=%s" \
			% [machine.current_name, is_on_floor(), coyote, is_slimed()])
	else:
		jump_buffer_t = maxf(0.0, jump_buffer_t - delta)
	invuln = maxf(0.0, invuln - delta)
	roll_cd = maxf(0.0, roll_cd - delta)

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
	floor_snap_length = JUMP_FLOOR_SNAP if velocity.y > 0.0 else GROUND_FLOOR_SNAP

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

## How far off dead-vertical (for the wall) or dead-flat (for the ledge top)
## a surface's normal is allowed to be and still count as grabbable — ledge
## hang only ever catches a perfectly flat, unrotated ledge, never a beveled
## edge, a sloped roof, or anything else even slightly tilted.
const LEDGE_MAX_TILT := 0.05

## Looks for a grabbable ledge directly ahead while falling — a forward probe
## at roughly chest height finds a wall, then a downward probe just past it
## looks for a surface near that same height (the ledge's own top edge, not
## a wall that just keeps going well above or below reach). Both the wall
## and the ledge top must come back perfectly flat (see LEDGE_MAX_TILT) —
## any rotation on either surface disqualifies it. Called from AirState
## every frame while falling; returns {} when nothing qualifies, otherwise
## wall_normal/hang_pos for LedgeHangState to use.
## NOTE: geometry-sensitive and untested against real level art — tune the
## Ledge Hang numbers in PlayerConfig once there's an actual ledge to grab.
func find_ledge() -> Dictionary:
	var dir := get_hvel()
	dir = dir if dir.length() > 0.1 else -facing
	dir = Vector3(dir.x, 0.0, dir.z)
	if dir.length() < 0.001:
		return {}
	dir = dir.normalized()

	var space := get_world_3d().direct_space_state
	var probe_origin := global_position + Vector3.UP * config.ledge_grab_height
	var fwd_to := probe_origin + dir * (RADIUS + config.ledge_grab_forward_offset)
	var fwd_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		probe_origin, fwd_to, collision_mask, [get_rid()]))
	if fwd_hit.is_empty():
		return {}

	var normal: Vector3 = fwd_hit.normal
	if absf(normal.y) > LEDGE_MAX_TILT:
		return {}   # not a perfectly vertical wall — tilted/rotated, so not grabbable
	normal.y = 0.0
	normal = normal.normalized()
	if (-dir).dot(normal) < 0.5:
		return {}   # too glancing an angle — not squarely facing the wall

	var hit_xz: Vector3 = fwd_hit.position
	var probe_xz := hit_xz - normal * 0.05   # nudge past the wall face, into open space above it
	var tol := config.ledge_grab_vertical_tolerance
	var down_from := Vector3(probe_xz.x, global_position.y + config.ledge_grab_height + tol, probe_xz.z)
	var down_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		down_from, down_from + Vector3.DOWN * (tol * 2.0), collision_mask, [get_rid()]))
	if down_hit.is_empty():
		return {}   # the wall keeps going well above grab height — nothing to grab here
	if down_hit.normal.dot(Vector3.UP) < 1.0 - LEDGE_MAX_TILT:
		return {}   # not a perfectly flat, level ledge top — tilted/rotated, so not grabbable

	var top_y: float = down_hit.position.y
	if top_y < global_position.y + config.ledge_grab_height - tol:
		return {}   # whatever's down there is below grab height — not reachable from here

	var hang_pos := hit_xz + normal * config.ledge_hang_offset
	hang_pos.y = top_y - STAND_HEIGHT * 0.5
	return {"wall_normal": normal, "hang_pos": hang_pos}

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
func try_wall_bounce(prev_hvel: Vector3, regrants_dive: bool, bounce_anim: StringName,
		bounce_time: float, allow_grounded := false) -> bool:
	if (is_on_floor() and not allow_grounded) or not is_on_wall() or prev_hvel.length() < config.wall_min_speed:
		return false
	var n := get_wall_normal()
	n.y = 0.0
	if n.length() < 0.1:
		return false
	n = n.normalized()
	if (-prev_hvel.normalized()).dot(n) < 0.35:
		return false
	velocity = n * config.wall_bounce_push
	velocity.y = config.wall_bounce_up
	face(n)
	visual.play_hold(bounce_anim, bounce_time)
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

# ---------------------------------------------------------------- damage

func hit(amount: float, pierces_shield := false) -> void:
	if dead or invuln > 0.0 or Game.god_mode:
		return
	invuln = HIT_INVULN
	visual.flash()
	if Game.stats.take_damage(amount, pierces_shield):
		dead = true
		velocity = Vector3.ZERO
		Events.player_died.emit()
