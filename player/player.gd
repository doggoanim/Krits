class_name Player
extends CharacterBody3D
## Platformer controller. Movement logic lives in states/; this class owns the
## shared physics helpers, timers and the stat/damage interface.

@export var config: PlayerConfig = PlayerConfig.new()

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const RADIUS := 0.4
const HIT_INVULN := 0.8

var camera_rig: CameraRig
var visual: PlayerVisual
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
var _prev_facing_yaw := 0.0

func _ready() -> void:
	collision_layer = 1 << 1   # layer 2: player
	collision_mask = 1 | (1 << 6)   # layer 1: world, layer 7: arena walls
	add_to_group(&"player")
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)

	_shape = CapsuleShape3D.new()
	_shape.radius = RADIUS
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = _shape
	add_child(_shape_node)
	set_crouching(false)

	visual = PlayerVisual.new()
	add_child(visual)

	machine = StateMachine.new()
	machine.name = "StateMachine"
	add_child(machine)
	machine.setup(self, {
		&"Ground": GroundState.new(), &"Crouch": CrouchState.new(),
		&"Roll": RollState.new(), &"Air": AirState.new(),
		&"LongJump": LongJumpState.new(), &"Dive": DiveState.new(),
		&"Pound": PoundState.new(), &"PoundLand": PoundLandState.new(),
		&"Frozen": FrozenState.new(),
	})
	machine.start(&"Ground")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_timers(delta)
	machine.physics_update(delta)
	if is_on_floor() and not _was_on_floor:
		can_dive = true
		Events.player_landed.emit()
	_was_on_floor = is_on_floor()
	_update_lean(delta)

## Arcade-style motion lean: pitch forward with ground speed, bank into turns.
## Grounded only — cinematic poses (dive/pound/long jump) already claim `_body`'s
## own rotation, and fading this out in the air keeps the two from ever mixing.
func _update_lean(delta: float) -> void:
	var yaw := atan2(-facing.x, -facing.z)
	var yaw_rate := wrapf(yaw - _prev_facing_yaw, -PI, PI) / maxf(delta, 0.0001)
	_prev_facing_yaw = yaw

	var target_pitch := 0.0
	var target_bank := 0.0
	if is_on_floor():
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

# ---------------------------------------------------------------- actions

## Every jump is a fixed, snappy height — no variable height from holding the
## button, so the timing always feels the same regardless of how long jump is held.
func start_jump(vel: float) -> void:
	velocity.y = vel
	coyote = 0.0
	jump_buffer_t = 0.0
	machine.transition_to(&"Air")

func bounce_off_orb() -> void:
	set_hvel(Vector3.ZERO)   # a clean vertical pop, even out of a fast dive
	velocity.y = config.orb_bounce_velocity
	can_dive = true
	machine.transition_to(&"Air")

## Call after move_and_slide() from Dive / LongJump with the pre-move horizontal velocity.
## Each source bounces once: a long-jump bounce re-grants the dive (so a dive can
## bounce too), a dive bounce does not, so the chain ends there until you land.
func try_wall_bounce(prev_hvel: Vector3, regrants_dive: bool) -> bool:
	if is_on_floor() or not is_on_wall() or prev_hvel.length() < config.wall_min_speed:
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
	if regrants_dive:
		can_dive = true
	# Same hygiene as start_jump(): a wall bounce counts as a jump, so make sure
	# a leftover buffered jump / coyote window can't immediately re-fire a second,
	# different jump on top of it the moment AirState ticks next frame.
	coyote = 0.0
	jump_buffer_t = 0.0
	machine.transition_to(&"Air")
	return true

func set_crouching(c: bool) -> void:
	var h := CROUCH_HEIGHT if c else STAND_HEIGHT
	_shape.height = h
	_shape_node.position.y = h * 0.5
	if visual:
		visual.set_crouch(c)

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
