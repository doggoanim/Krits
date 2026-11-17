class_name SwingingSign
extends Node3D
## The hanging part of a shop sign (chains, board, lettering) as a pendulum around the
## iron rod it hangs from, so it sways like a real sign: the shared wind (WindGusts) pushes
## it out from the wall in gusts, it swings back under gravity and settles with a damped
## wobble, it can't swing into the wall (it taps it and bounces off), and someone running
## past underneath sets it rocking a little. Local +Z is out of the wall.
##
## The node's origin is the rod; everything it holds hangs below it. Nothing runs in the editor.

const GRAVITY_OVER_LENGTH := 11.0   ## pendulum stiffness (g / effective length): ~1.9 s per swing
const DAMPING := 0.6                ## higher settles faster
const WIND_PUSH := 2.4              ## angular acceleration (rad/s^2) per unit of gust above calm
const MIN_ANGLE := -0.05            ## swing towards the wall stops almost at once (the board hangs close to it)
const MAX_ANGLE := 0.75             ## and this far out
const BOUNCE := 0.4                 ## how much speed is kept when it taps the wall
const PASSER_RANGE := 2.4           ## a moving player this near (horizontally) stirs it
const PASSER_PUSH := 0.05           ## rad/s^2 per m/s of the player's speed, at point blank

var _angle := 0.0   ## how far the board is swung OUT from the wall, radians
var _omega := 0.0
var _player: Node3D
var _phase := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_phase = randf() * 100.0
	_omega = randf_range(-0.15, 0.15)   # not every sign starts perfectly still
	_player = get_tree().get_first_node_in_group(&"player") as Node3D

func _physics_process(delta: float) -> void:
	var clock := Time.get_ticks_msec() / 1000.0
	var gust := WindGusts.sample(Vector2(global_position.x, global_position.z), clock) - WindGusts.BASE_LEVEL
	var alpha := -GRAVITY_OVER_LENGTH * sin(_angle) - DAMPING * _omega + gust * WIND_PUSH
	alpha += sin(clock * 1.7 + _phase) * 0.12   # a constant little restlessness
	alpha += _passer_push()
	_omega += alpha * delta
	_angle += _omega * delta
	if _angle < MIN_ANGLE:
		_angle = MIN_ANGLE
		_omega = absf(_omega) * BOUNCE
	elif _angle > MAX_ANGLE:
		_angle = MAX_ANGLE
		_omega = -absf(_omega) * BOUNCE
	rotation.x = -_angle   # a positive angle swings the hanging board towards +Z

## Airflow behind someone moving past: a small shove along the wall's normal.
func _passer_push() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	var local := global_transform.affine_inverse() * _player.global_position
	var distance := Vector2(local.x, local.z).length()
	if distance > PASSER_RANGE:
		return 0.0
	var speed := 0.0
	if "velocity" in _player:
		var v: Vector3 = _player.velocity
		speed = Vector2(v.x, v.z).length()
	if speed < 1.0:
		return 0.0
	return -signf(local.z) * PASSER_PUSH * speed * (1.0 - distance / PASSER_RANGE)
