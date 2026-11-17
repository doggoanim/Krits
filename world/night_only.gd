class_name NightOnly
extends Node
## Bolt-on: add as a child of a particle system (fireflies, a night mist) or any
## node, and its parent switches on after dusk and off at dawn, following
## WorldClock. `day_only` flips it for things that belong to daylight (dust
## motes in a sunbeam, butterflies).
##
## GPUParticles3D parents get `emitting` toggled (so existing particles fade
## out naturally instead of vanishing); anything else gets `visible`.

@export var day_only := false
## How dark (0..1, WorldClock.night_amount) before the parent switches on.
## For day_only, the same number of daylight.
@export_range(0.05, 0.95) var threshold := 0.5

var _parent: Node
var _state := -1   ## -1 unknown, 0 off, 1 on

func _ready() -> void:
	_parent = get_parent()
	if Engine.is_editor_hint() or _parent == null:
		set_process(false)

func _process(_delta: float) -> void:
	var on := WorldClock.night_amount() > threshold
	if day_only:
		on = WorldClock.day_amount() > threshold
	var want := 1 if on else 0
	if want == _state:
		return
	_state = want
	if _parent is GPUParticles3D:
		(_parent as GPUParticles3D).emitting = on
	elif _parent is CPUParticles3D:
		(_parent as CPUParticles3D).emitting = on
	elif _parent is Node3D:
		(_parent as Node3D).visible = on
