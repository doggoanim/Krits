class_name TutorialPopup
extends Control
## A "learn this key" card that pauses the game: the action's current
## (rebindable) key plate next to a line of text, e.g. [F] to toggle the
## Lantern. Anything asks with Events.tutorial_popup_requested(id, action, text)
## where `text` is BBCode ([color=...] to highlight the thing being taught). It
## opens once the item-get fanfare / any conversation has finished, closes when
## the player presses the very key it shows, and is remembered as the story flag
## `tutorial_<id>` so it never shows twice. Requests queue up one after another.

const PLATE_SCENE := preload("res://ui/widgets/key_hint_plate.tscn")
const BOTTOM_MARGIN := 50.0   ## same gap the dialogue box leaves
const FADE_TIME := 0.2
const MIN_OPEN_TIME := 0.35   ## ignore the key briefly so a held press can't skip the card

var _queue: Array[Dictionary] = []
var _showing := false
var _open_time := 0.0
var _id: StringName = &""
var _action: StringName = &""   ## the action the card teaches — pressing it closes the card
var _panel: PanelContainer
var _row: HBoxContainer
var _label: RichTextLabel
var _plate: KeyHintPlate

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # runs while it holds the game paused
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	Events.tutorial_popup_requested.connect(_on_requested)

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	# Sits where the dialogue box does: bottom centre, just above the screen edge.
	var anchor := VBoxContainer.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.alignment = BoxContainer.ALIGNMENT_END
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_theme_constant_override("separation", 0)
	add_child(anchor)
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	anchor.add_child(_panel)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, BOTTOM_MARGIN)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(gap)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_panel.add_child(margin)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 28)
	margin.add_child(_row)
	_plate = PLATE_SCENE.instantiate() as KeyHintPlate
	_row.add_child(_plate)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.add_theme_font_size_override("normal_font_size", 44)
	_label.add_theme_font_size_override("bold_font_size", 44)
	_row.add_child(_label)

func _on_requested(id: StringName, action: StringName, text: String) -> void:
	if Game.flag(_flag(id)):
		return
	for entry in _queue:
		if entry["id"] == id:
			return
	if _showing and _id == id:
		return
	_queue.append({"id": id, "action": action, "text": text})
	set_process(true)

func _flag(id: StringName) -> StringName:
	return StringName("tutorial_%s" % id)

func _process(delta: float) -> void:
	if _showing:
		_open_time += delta
		return
	if _queue.is_empty():
		set_process(false)
		return
	if _can_show():
		_show(_queue.pop_front())

## Waits for the item-get fanfare, conversations, menus and death to be over.
func _can_show() -> bool:
	if ItemGet.instance != null and ItemGet.instance.is_playing():
		return false
	if DialogueBox.instance != null and DialogueBox.instance.is_active():
		return false
	if MenuBase.open_menu != null or get_tree().paused or Game.input_locked:
		return false
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player == null or not player.dead

func _show(entry: Dictionary) -> void:
	_showing = true
	_open_time = 0.0
	_id = entry["id"]
	_action = entry["action"]
	_plate.set_key(InputSetup.key_label(Settings.get_binding(entry["action"])))
	_label.text = entry["text"]
	modulate.a = 0.0
	visible = true
	get_tree().paused = true
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)

func _input(event: InputEvent) -> void:
	if not _showing or _open_time < MIN_OPEN_TIME:
		return
	if event.is_action_pressed(_action):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	_showing = false
	Game.set_flag(_flag(_id))
	visible = false
	get_tree().paused = false
