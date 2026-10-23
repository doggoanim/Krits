class_name RagdollState
extends PlayerState
## A brief forced "knockdown" — not a real physics skeleton (the model has no
## physical bones rigged), just a visual tumble layered on top of the normal
## CharacterBody3D falling/settling, the same trick Enemy._do_leap_attack()
## uses for its own airborne tumble. Entered by Arena when the Staff's rune
## buffer overflows (see Arena._overload_staff()).
##
## No input is read here at all — gravity still applies and move_and_slide()
## still runs (so a mid-air overload still falls and lands normally), but
## nothing steers it. Held for at least MIN_TIME regardless of when it's
## entered, then waits for a jump press to stand back up.

const MIN_TIME := 1.0
const SPIN_SPEED_MIN := 3.0   ## rad/s
const SPIN_SPEED_MAX := 6.0
const SETTLE_TIME := 0.35     ## how long the spin takes to damp down to a held "lying flat" pose

var _t := 0.0
var _spin_axis := Vector3.RIGHT
var _spin_speed := 0.0

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_t = 0.0
	p.set_hvel(Vector3.ZERO)
	p.visual.cancel_hold()
	# Not baked into the model yet — PlayerVisual.play() just warns and no-ops
	# until it is, same as the wall-climb clips before those existed; the
	# spin below sells the tumble either way.
	p.visual.play(PlayerVisual.ANIM_RAGDOLL)
	_spin_axis = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_spin_axis = _spin_axis.normalized() if _spin_axis.length() > 0.01 else Vector3.RIGHT
	_spin_speed = randf_range(SPIN_SPEED_MIN, SPIN_SPEED_MAX)

## Resets the model upright — Player._update_lean() resumes driving
## rotation.x/z the instant the next state's physics_update() runs, but
## rotation.y (yaw) is only ever touched by face(), so it needs resetting
## here or the player would stand back up still facing however the tumble
## happened to leave them.
func exit(_next: StringName) -> void:
	player.visual.rotation = Vector3.ZERO

func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	p.apply_gravity(delta)
	p.move_and_slide()

	# Spins fast at first, damping to a stop so it settles into a held pose
	# instead of tumbling the whole time.
	var damp := clampf(1.0 - _t / SETTLE_TIME, 0.0, 1.0)
	if damp > 0.0:
		p.visual.rotate(_spin_axis, _spin_speed * damp * delta)

	if _t >= MIN_TIME and Input.is_action_just_pressed(&"jump"):
		machine.transition_to(&"Air" if not p.is_on_floor() else &"Ground")
