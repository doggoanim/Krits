@tool
class_name SteppedSwing
extends Node
## Bolt-on: swings its parent back and forth around an axis between two angles (a
## weathervane, a hanging board...), in held poses (see Choppy) instead of a smooth
## blend. Parent's rest rotation is ignored: the angle is set outright.

@export var axis := Vector3.UP
@export var from_degrees := -30.0
@export var to_degrees := 30.0
@export var period := 6.0              ## seconds for a full there-and-back
@export var phase := 0.0               ## seconds of offset, so neighbours don't swing in step

var _last := -1
var _target: Node3D

func _ready() -> void:
	_target = get_parent() as Node3D
	if _target == null or Engine.is_editor_hint():
		set_process(false)

func _process(_delta: float) -> void:
	var idx := Choppy.index()
	if idx == _last:
		return
	_last = idx
	var wave := sin((Choppy.time() + phase) / period * TAU) * 0.5 + 0.5
	var angle := deg_to_rad(lerpf(from_degrees, to_degrees, wave))
	_target.basis = Basis(axis.normalized(), angle)
