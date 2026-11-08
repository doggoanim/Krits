class_name TutorialPopup
extends Control
## A "learn this key" card that pauses the game: one row per move, each a key
## plate (the action's current, rebindable key), an optional dim context tag
## ("Ground", "Air") and the move's name, e.g.
##   [Ctrl] [Ground] Crouch
##   [Ctrl] [Air]    Ground Pound
## Ask with Events.tutorial_popup_requested(id, rows), rows being dictionaries
## {action: StringName, tag: String, text: String (BBCode)}. It opens once the
## item-get fanfare / any conversation has finished, closes when the player
## presses the first row's key, and is remembered as the story flag
## `tutorial_<id>` so it never shows twice. Requests queue up one after another.

const PLATE_SCENE := preload("res://ui/widgets/key_hint_plate.tscn")
const BOTTOM_FRACTION := 0.3   ## how far up the screen the card floats (0 = on the bottom edge, 0.5 = dead centre)
const TAG_WIDTH := 200.0
const TAG_COLOR := Color(0.62, 0.75, 0.85)
const FONT_SIZE := 44
const FADE_TIME := 0.2
const MIN_OPEN_TIME := 1.0   ## ignore the key briefly so a held press can't skip the card

var _queue: Array[Dictionary] = []
var _showing := false
var _open_time := 0.0
var _id: StringName = &""
var _action: StringName = &""   ## the first row's action — pressing it closes the card
var _panel: PanelContainer
var _gap: Control
var _rows: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # runs while it holds the game paused
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	get_viewport().size_changed.connect(_fit_to_screen)
	Events.tutorial_popup_requested.connect(_on_requested)

## Belt and braces for a Control parented to a CanvasLayer: pin the root to the
## whole screen explicitly so the bottom-centre layout below has a real size.
func _fit_to_screen() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_gap.custom_minimum_size = Vector2(0, size.y * BOTTOM_FRACTION)

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.4)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	# Bottom-up stack: card, then a gap that lifts it to a little below screen centre.
	var anchor := VBoxContainer.new()
	anchor.alignment = BoxContainer.ALIGNMENT_END
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_theme_constant_override("separation", 0)
	add_child(anchor)
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	anchor.add_child(_panel)
	_gap = Control.new()
	_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_gap)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_panel.add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 18)
	margin.add_child(_rows)

## Rebuilds the card's rows from {action, tag, text} dictionaries.
func _fill(rows: Array) -> void:
	for c in _rows.get_children():
		c.queue_free()
	for entry: Dictionary in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 28)
		_rows.add_child(line)
		var plate := PLATE_SCENE.instantiate() as KeyHintPlate
		line.add_child(plate)
		plate.set_key(InputSetup.key_label(Settings.get_binding(entry["action"])))
		var tag: String = entry.get("tag", "")
		if tag != "":
			var tag_label := Label.new()
			tag_label.text = "[%s]" % tag
			tag_label.custom_minimum_size = Vector2(TAG_WIDTH, 0)
			tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tag_label.add_theme_font_size_override("font_size", FONT_SIZE)
			tag_label.add_theme_color_override("font_color", TAG_COLOR)
			line.add_child(tag_label)
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.scroll_active = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
		label.add_theme_font_size_override("bold_font_size", FONT_SIZE)
		label.text = entry["text"]
		line.add_child(label)

func _on_requested(id: StringName, rows: Array) -> void:
	if Game.flag(_flag(id)):
		return
	for entry in _queue:
		if entry["id"] == id:
			return
	if _showing and _id == id:
		return
	if rows.is_empty():
		return
	_queue.append({"id": id, "rows": rows})
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
	_action = entry["rows"][0]["action"]
	_fill(entry["rows"])
	modulate.a = 0.0
	visible = true
	_fit_to_screen()
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
