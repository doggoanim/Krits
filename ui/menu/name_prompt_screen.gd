class_name NamePromptScreen
extends MenuScreen
## "What's my name?" — and the gag: the moment the player types a single
## character, the name box snaps to "Krits", and the game's shared
## DialogueBox (see ui/dialogue_box.gd — the same one every conversation in
## the game uses, built once by MainMenu) says Krits remembers it now. When
## that line is dismissed, the new-game save for the chosen slot is created
## and the game starts (see MainMenu's &"game" target).
##
## Esc backs out to the slot screen, but only until that first character —
## once the name's been "remembered" there's no going back.

const FORCED_NAME := "Krits"
const REMEMBER_LINE := "oh yeah I remember it now"
## Beat between the box snapping to the real name and the dialogue appearing.
const DIALOGUE_DELAY := 0.7

@onready var _name_edit: LineEdit = %NameEdit

var _slot := 1
var _locked := false

func _ready() -> void:
	_name_edit.text_changed.connect(_on_text_changed)

func enter(payload: Dictionary = {}) -> void:
	_slot = payload.get("slot", 1)
	_locked = false
	_name_edit.text = ""
	_name_edit.editable = true
	_name_edit.focus_mode = Control.FOCUS_ALL
	_name_edit.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and not _locked and event.is_action_pressed(&"ui_cancel_menu"):
		get_viewport().set_input_as_handled()
		navigate.emit(&"slots", {})

func _on_text_changed(_new_text: String) -> void:
	if _locked:
		return
	_locked = true
	_name_edit.text = FORCED_NAME
	_name_edit.caret_column = FORCED_NAME.length()
	_name_edit.editable = false
	# Drop focus entirely, not just editability: otherwise the LineEdit keeps
	# swallowing key presses, including the E that advances the dialogue.
	_name_edit.release_focus()
	_name_edit.focus_mode = Control.FOCUS_NONE
	await get_tree().create_timer(DIALOGUE_DELAY).timeout
	_say_remember_line()

func _say_remember_line() -> void:
	if DialogueBox.instance == null:
		_start_game()
		return
	Events.dialogue_ended.connect(_start_game, CONNECT_ONE_SHOT)
	var line := DialogueNode.new()
	line.speaker = FORCED_NAME
	line.text = REMEMBER_LINE
	DialogueBox.instance.start(line)

func _start_game() -> void:
	navigate.emit(&"game", {"slot": _slot, "new_game": true, "name": FORCED_NAME})
