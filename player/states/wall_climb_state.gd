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
## to move, trying the current normal first and then that direction rotated
## by increasing angles. A flat wall just keeps re-hitting the same normal;
## a corner's probe comes back with a different one, and that's the wrap.

var _normal := Vector3.FORWARD
var _attach_point := Vector3.ZERO

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	var p := player
	_normal = _msg.get("normal", Vector3.FORWARD)
	_attach_point = _msg.get("point", p.global_position)
	p.velocity = Vector3.ZERO
	p.can_dive = true
	_snap_to_wall()
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
		var found := p.probe_wall_near(tentative, _normal)
		if not found.is_empty():
			_attach_point = found.point
			_normal = found.normal
		# If nothing climbable is found near where we tried to go, treat it
		# like a solid edge and just don't move that frame — same fallback
		# as any other blocked movement, rather than falling off the first
		# untagged border you reach.

	_snap_to_wall()
	p.face(-_normal, delta)
	p.velocity = Vector3.ZERO
	p.visual.play(PlayerVisual.ANIM_WALL_CLIMB if moving else PlayerVisual.ANIM_WALL_CLIMB_IDLE)

	if Input.is_action_pressed(&"crouch_pound"):
		machine.transition_to(&"Air")
		return

	if p.jump_buffer_t > 0.0:
		p.jump_off_wall(_normal)

func _snap_to_wall() -> void:
	var p := player
	p.global_position = _attach_point + _normal * p.config.wall_hug_distance

## A horizontal "sideways along the wall" axis for `normal` — arbitrary in
## the sense that which way ends up "right" vs "left" isn't guaranteed to
## match a given wall's own art/orientation, but it's consistent frame to
## frame, which is all steering here actually needs.
func _wall_right(normal: Vector3) -> Vector3:
	var right := normal.cross(Vector3.UP)
	return right.normalized() if right.length() > 0.01 else Vector3.RIGHT
