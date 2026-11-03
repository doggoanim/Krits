class_name PendulumSwing
extends RefCounted
## The damped-spring "hanging thing" motion shared by worn gear (the sword on
## the shield, the hip lantern): motion of the anchor it hangs from, measured
## in the anchor's own frame, pulls it off-centre — forward/back speed pitches
## it, sideways speed rolls it — so it trails when you run, kicks when you stop
## and settles back. step() returns (pitch, roll) in radians; apply it as
## `pivot.rotation = Vector3(s.x, 0.0, s.y)`.

var strength := 0.06   ## radians of swing per m/s of anchor speed
var max_angle := 0.7   ## radians
var follow := 12.0     ## spring stiffness (higher = snappier)
var damping := 4.0     ## higher = settles faster, less wobble

var _angle := Vector2.ZERO
var _velocity := Vector2.ZERO

func step(local_velocity: Vector3, delta: float) -> Vector2:
	var target := Vector2(
		clampf(local_velocity.z * strength, -max_angle, max_angle),
		clampf(-local_velocity.x * strength, -max_angle, max_angle))
	var accel := (target - _angle) * follow * follow - _velocity * 2.0 * damping
	_velocity += accel * delta
	_angle += _velocity * delta
	return _angle
