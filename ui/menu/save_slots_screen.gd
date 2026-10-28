class_name SaveSlotsScreen
extends MenuScreen
## Three tall slot rectangles (left / middle / right) plus a small Return
## button bottom-right. An occupied slot loads straight into the game; an
## empty one starts the new-game flow (name prompt) for that slot. Slot
## contents come from Game.slot_summary() — it never loads a save into live
## state just to label it.
##
## Each occupied slot also has a Delete button underneath it. Deleting always
## goes through a Yes/Cancel confirmation overlay so a stray click can't wipe
## a save; Esc cancels the confirmation before it backs out of the screen.

var _slot_buttons: Array[Button] = []
var _delete_buttons: Array[Button] = []
var _pending_delete := 0   ## slot awaiting confirmation; 0 = no dialog open

@onready var _slots: HBoxContainer = %Slots
@onready var _return: Button = %ReturnButton
@onready var _delete_row: HBoxContainer = %DeleteRow
@onready var _confirm: Control = %Confirm
@onready var _confirm_message: Label = %Message
@onready var _yes: Button = %YesButton
@onready var _no: Button = %NoButton

func _ready() -> void:
	for n in _slots.get_children():
		if n is Button:
			_slot_buttons.append(n)
	for i in _slot_buttons.size():
		_slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i + 1))
	for n in _delete_row.get_children():
		if n is Button:
			_delete_buttons.append(n)
	for i in _delete_buttons.size():
		_delete_buttons[i].pressed.connect(_ask_delete.bind(i + 1))
	_yes.pressed.connect(_confirm_delete)
	_no.pressed.connect(_close_confirm)
	_return.pressed.connect(_go_back)

func enter(_payload: Dictionary = {}) -> void:
	_close_confirm(false)
	_refresh()
	_slot_buttons[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel_menu"):
		get_viewport().set_input_as_handled()
		if _pending_delete != 0:
			_close_confirm()
		else:
			_go_back()

func _refresh() -> void:
	for i in _slot_buttons.size():
		var slot := i + 1
		var summary := Game.slot_summary(slot)
		if summary.is_empty():
			_slot_buttons[i].text = "Slot %d\n\nEmpty" % slot
		else:
			_slot_buttons[i].text = "Slot %d\n\n%s\n\nGold: %d" % [slot, summary["name"], summary["gold"]]

	_refresh_delete_buttons()

## A Delete button only makes sense under a slot that has a save. Empty
## slots' buttons are made invisible and inert rather than hidden: hiding one
## would remove it from the row's layout and slide the others out from under
## their slots.
func _refresh_delete_buttons() -> void:
	for i in _delete_buttons.size():
		var used := Game.has_save(i + 1)
		var button := _delete_buttons[i]
		button.modulate.a = 1.0 if used else 0.0
		button.disabled = not used
		button.focus_mode = Control.FOCUS_ALL if used else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if used else Control.MOUSE_FILTER_IGNORE

func _ask_delete(slot: int) -> void:
	_pending_delete = slot
	_confirm_message.text = "Delete Slot %d?\nThis can't be undone." % slot
	_confirm.visible = true
	_no.grab_focus()   # default to the safe choice

func _confirm_delete() -> void:
	var slot := _pending_delete
	_close_confirm(false)
	Game.delete_save(slot)
	_refresh()
	_slot_buttons[slot - 1].grab_focus()

func _close_confirm(refocus := true) -> void:
	var slot := _pending_delete
	_pending_delete = 0
	_confirm.visible = false
	if refocus and slot != 0:
		_delete_buttons[slot - 1].grab_focus()

func _on_slot_pressed(slot: int) -> void:
	if Game.has_save(slot):
		navigate.emit(&"game", {"slot": slot})
	else:
		navigate.emit(&"name", {"slot": slot})

func _go_back() -> void:
	navigate.emit(&"title", {"show_menu": true})
