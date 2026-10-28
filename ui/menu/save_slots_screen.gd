class_name SaveSlotsScreen
extends MenuScreen
## Three tall slot rectangles (left / middle / right) plus a small Return
## button bottom-right. An occupied slot loads straight into the game; an
## empty one starts the new-game flow (name prompt) for that slot. Slot
## contents come from Game.slot_summary() — it never loads a save into live
## state just to label it.

var _slot_buttons: Array[Button] = []

@onready var _slots: HBoxContainer = %Slots
@onready var _return: Button = %ReturnButton

func _ready() -> void:
	for n in _slots.get_children():
		if n is Button:
			_slot_buttons.append(n)
	for i in _slot_buttons.size():
		_slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i + 1))
	_return.pressed.connect(_go_back)

func enter(_payload: Dictionary = {}) -> void:
	_refresh()
	_slot_buttons[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel_menu"):
		get_viewport().set_input_as_handled()
		_go_back()

func _refresh() -> void:
	for i in _slot_buttons.size():
		var slot := i + 1
		var summary := Game.slot_summary(slot)
		if summary.is_empty():
			_slot_buttons[i].text = "Slot %d\n\nEmpty" % slot
		else:
			_slot_buttons[i].text = "Slot %d\n\n%s\n\nGold: %d" % [slot, summary["name"], summary["gold"]]

func _on_slot_pressed(slot: int) -> void:
	if Game.has_save(slot):
		navigate.emit(&"game", {"slot": slot})
	else:
		navigate.emit(&"name", {"slot": slot})

func _go_back() -> void:
	navigate.emit(&"title", {"show_menu": true})
