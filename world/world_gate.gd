class_name WorldGate
extends StaticBody3D
## Blocks a passage until `required_flag` is set true (via Game.set_flag),
## then opens itself automatically — no reload needed, since it listens for
## the flag live. Build it like any other solid obstacle in the editor: give
## it a CollisionShape3D and whatever visual you want (rubble, a sealed door,
## a magic barrier) as children.

@export var required_flag: StringName = &""

signal opened   ## connect this for a custom open animation/sound later

func _ready() -> void:
	Events.story_flag_changed.connect(_on_flag_changed)
	if required_flag != &"" and Game.flag(required_flag):
		_open()

func _on_flag_changed(flag: StringName, value: Variant) -> void:
	if flag == required_flag and value:
		_open()

func _open() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	visible = false
	opened.emit()
