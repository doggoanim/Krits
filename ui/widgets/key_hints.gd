class_name KeyHints
extends Control
## Wordless "press this key" plates at the top centre of the screen. Anything
## can ask for one with Events.key_hint_requested(id, action, done_states): a
## plate showing the action's current (rebindable) key fades in and stays until
## the player enters one of `done_states` (a player state id such as Roll) or
## someone emits Events.key_hint_dismissed(id). Learned hints are remembered
## as the story flag `tutorial_<id>` and never shown again, so requesters can
## simply ask every time. Several hints sit side by side.

const PLATE_SCENE := preload("res://ui/widgets/key_hint_plate.tscn")
const FADE_TIME := 0.25

class Hint:
	var plate: KeyHintPlate
	var done_states: Array[StringName] = []

@onready var _row: HBoxContainer = %Row

var _hints: Dictionary = {}   ## id -> Hint

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.key_hint_requested.connect(_on_requested)
	Events.key_hint_dismissed.connect(_dismiss)
	Events.player_state_changed.connect(_on_player_state)

func _flag(id: StringName) -> StringName:
	return StringName("tutorial_%s" % id)

func _on_requested(id: StringName, action: StringName, done_states: Array[StringName]) -> void:
	if _hints.has(id) or Game.flag(_flag(id)):
		return
	var hint := Hint.new()
	hint.done_states = done_states
	hint.plate = PLATE_SCENE.instantiate() as KeyHintPlate
	hint.plate.modulate.a = 0.0
	_row.add_child(hint.plate)
	hint.plate.set_key(InputSetup.key_label(Settings.get_binding(action)))
	create_tween().tween_property(hint.plate, "modulate:a", 1.0, FADE_TIME)
	_hints[id] = hint

func _on_player_state(state: StringName) -> void:
	for id: StringName in _hints.keys():
		var hint: Hint = _hints[id]
		if state in hint.done_states:
			_dismiss(id)

## Fades the plate out and remembers the hint as learned.
func _dismiss(id: StringName) -> void:
	if not _hints.has(id):
		return
	var hint: Hint = _hints[id]
	_hints.erase(id)
	Game.set_flag(_flag(id))
	var tween := create_tween()
	tween.tween_property(hint.plate, "modulate:a", 0.0, FADE_TIME * 2.0)
	tween.tween_callback(hint.plate.queue_free)
