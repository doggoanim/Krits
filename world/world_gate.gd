class_name WorldGate
extends StaticBody3D
## Blocks a passage until `required_flag` is set true (via Game.set_flag),
## then opens itself automatically — no reload needed, since it listens for
## the flag live. Build it like any other solid obstacle in the editor: give
## it a CollisionShape3D and whatever visual you want (rubble, a sealed door,
## a magic barrier) as children.
##
## Opening crumbles the gate's own geometry away via WorldDissolver
## (world/world_dissolver.gd) instead of an instant visible=false pop — the
## same noise-crumble shader used for other one-off "make this go away"
## moments, here given a default home instead of sitting unused. `opened` is
## still emitted right away (not after the dissolve finishes) for anyone who
## wants to layer a sound or a custom effect on top; it doesn't need to wait,
## since the dissolve runs independently of whatever a listener does with it.

@export var required_flag: StringName = &""
@export var dissolve_time := 0.9   ## seconds for the crumble to finish once unlocked

signal opened   ## connect this for a custom open sound/effect alongside the dissolve

func _ready() -> void:
	Events.story_flag_changed.connect(_on_flag_changed)
	if required_flag != &"" and Game.flag(required_flag):
		_open(true)

func _on_flag_changed(flag: StringName, value: Variant) -> void:
	if flag == required_flag and value:
		_open(false)

## `instant` skips the animation entirely — used when the flag was already
## set on load (a returning player shouldn't watch every already-open gate
## replay its crumble every time the level loads).
func _open(instant: bool) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	opened.emit()
	if instant:
		visible = false
		return
	var dissolver := WorldDissolver.new()
	dissolver.begin(self)
	var tween := create_tween()
	tween.tween_method(dissolver.set_progress, 0.0, 1.0, dissolve_time)
	tween.tween_callback(func():
		dissolver.finish()
		visible = false)
