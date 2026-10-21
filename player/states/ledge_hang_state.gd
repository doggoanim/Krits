class_name LedgeHangState
extends PlayerState
## Hanging from a ledge edge, caught automatically while falling into one
## (see Player.find_ledge(), called from AirState). Deliberately minimal:
## every other move (roll/dive/pound, side flip, air steering, ...) is
## locked out just by this state never calling any of them — only crouch
## (drop down) and jump (climb up and over) do anything here.

var _wall_normal := Vector3.FORWARD
var _stand_pos := Vector3.ZERO
var _climbing := false
var _climb_t := 0.0
var _climb_start_pos := Vector3.ZERO

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_wall_normal = _msg.get("wall_normal", Vector3.FORWARD)
	_stand_pos = _msg.get("stand_pos", p.global_position)
	var hang_pos: Vector3 = _msg.get("hang_pos", p.global_position)
	p.velocity = Vector3.ZERO
	p.global_position = hang_pos
	p.face(-_wall_normal, -1.0)   # face into the wall you're hanging from
	p.can_dive = true   # dropping or climbing off counts as fresh footing, same as landing
	_climbing = false
	_climb_t = 0.0
	p.visual.cancel_hold()
	p.visual.play(PlayerVisual.ANIM_LEDGE_HANG)

func physics_update(delta: float) -> void:
	var p := player

	if _climbing:
		_update_climb(delta)
		return

	# Held in place — no drift, no gravity, no input-driven movement at all.
	p.velocity = Vector3.ZERO

	if Input.is_action_pressed(&"crouch_pound"):
		p.velocity.y = p.config.ledge_drop_speed
		machine.transition_to(&"Air")
		return

	if p.jump_buffer_t > 0.0:
		p.jump_buffer_t = 0.0
		_climbing = true
		_climb_t = 0.0
		_climb_start_pos = p.global_position
		p.visual.play_hold(PlayerVisual.ANIM_LEDGE_CLIMB, p.config.ledge_climb_time)

## Scripted, not physics-driven — same idea as FrozenState's "something else
## moves you" rather than letting move_and_slide fight a hand-authored arc.
## Plain lerp from the hang position to the ledge's stand position; swap for
## an actual arc/curve once the climb animation exists to match against.
func _update_climb(delta: float) -> void:
	var p := player
	_climb_t += delta
	var t := clampf(_climb_t / p.config.ledge_climb_time, 0.0, 1.0)
	p.global_position = _climb_start_pos.lerp(_stand_pos, t)
	if t >= 1.0:
		p.velocity = Vector3.ZERO
		machine.transition_to(&"Ground")
