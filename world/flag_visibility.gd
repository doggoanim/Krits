@tool
class_name FlagVisibility
extends Node
## Bolt-on: shows its parent only while story flags say so — the same idea as QuestProp's
## show_when / hide_when, for any decoration (a poster on a notice board, bunting that
## goes up once the town is saved). All of `show_when` must be set, and `hide_when`
## must not be. Re-checked whenever a story flag changes.

@export var show_when: Array[StringName] = []
@export var hide_when: StringName = &""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Events.story_flag_changed.connect(_on_flag_changed)
	_refresh()

func _on_flag_changed(_flag: StringName, _value: Variant) -> void:
	_refresh()

func _refresh() -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var shown := true
	for f in show_when:
		if not Game.flag(f):
			shown = false
	if hide_when != &"" and Game.flag(hide_when):
		shown = false
	parent.visible = shown
