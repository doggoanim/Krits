class_name PoundLandState
extends PlayerState
## Short recovery after a ground pound. Jumping here — or anywhere during the
## windup/slam that preceded it (see PoundState), or in the brief jump-buffer
## window right at the moment of landing — performs the high pound jump.

const IMPACT_FROM_DROP := 4.0     ## metres of fall before a pound starts hitting harder
const IMPACT_FULL_DROP := 20.0    ## metres for the full effect
const JUMP_BONUS := 0.35          ## the pound jump launches up to this much higher after a full-length fall

var _t := 0.0
var _impact := 0.0   ## 0..1 — how long the fall before the slam was

func enter(_prev: StringName, msg: Dictionary = {}) -> void:
	_t = player.config.pound_recover
	player.set_hvel(Vector3.ZERO)
	player.visual.cancel_hold()   # see RollState.enter()'s identical comment
	player.visual.play(PlayerVisual.ANIM_POUND_LAND)
	player.audio.play_pound_land()
	_impact = clampf((float(msg.get("drop", 0.0)) - IMPACT_FROM_DROP) / (IMPACT_FULL_DROP - IMPACT_FROM_DROP), 0.0, 1.0)
	var v := player.visual
	v.squash_stretch(lerpf(v.pound_land_squash_y, v.pound_land_squash_y * 0.6, _impact),
			lerpf(v.pound_land_squash_xz, v.pound_land_squash_xz * 1.2, _impact),
			v.pound_land_squash_time * (1.0 + _impact * 0.6))
	if player.camera_rig:
		player.camera_rig.shake(0.25 + 0.6 * _impact)
	if _impact > 0.0:
		player.effects.burst_land_dust()
		HitStop.freeze(0.04 + 0.08 * _impact)
	if msg.get("jump_queued", false):
		# A jump pressed during the fall (see PoundState.physics_update()) —
		# honor it right away instead of making the player land, let go of
		# jump, and press it again inside the recovery window. If this is a
		# no-op (e.g. the player landed in slime), physics_update()'s own
		# jump_buffer_t check below still covers a press made during recovery.
		player.start_jump(_jump_velocity(), true)
		if machine.current_name != &"PoundLand":
			return   # the jump actually took over — see start_jump()'s own transition

	# Landing on a steep slope skips the recovery pose entirely and hands
	# straight to Ground, whose own on_steep_slope check takes over
	# immediately — a pound into a slope should start sliding right away,
	# not stand planted through the whole recovery animation first.
	if player.is_on_floor() and player.get_floor_angle() >= deg_to_rad(player.config.slope_slide_angle_deg):
		machine.transition_to(&"Ground")

## A pound after a long fall springs back higher.
func _jump_velocity() -> float:
	return player.config.pound_jump_velocity * (1.0 + JUMP_BONUS * _impact)

func physics_update(delta: float) -> void:
	var p := player
	if p.jump_buffer_t > 0.0:
		p.start_jump(_jump_velocity(), true)
		return
	p.velocity = Vector3(0.0, -1.0, 0.0)
	p.safe_move_and_slide()
	_t -= delta
	if _t <= 0.0 or not p.is_on_floor():
		machine.transition_to(&"Ground")
