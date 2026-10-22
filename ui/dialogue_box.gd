class_name DialogueBox
extends CanvasLayer
## Drives one conversation at a time: shows a DialogueNode's speaker/text/
## portrait bottom-docked on screen, freezes the player for its duration
## (Player.enter_cinematic() — the same mechanism encounter transitions use),
## and walks the node graph as the player advances or picks a choice.
##
## Built here in code rather than as a .tscn — same "no separate scene file"
## convention as DebugTools' own debug HUD and WorldEnemy's placeholder
## visuals — so there's no hand-laid-out layout to keep in sync with this
## script. Instantiated once by UiRoot, same as Hud/StatsMenu/TravelMenu.

static var instance: DialogueBox

var _player: Player
var _current: DialogueNode

var _panel: PanelContainer
var _speaker_label: Label
var _text_label: RichTextLabel
var _portrait_rect: TextureRect
var _choice_list: VBoxContainer
var _continue_hint: Label

func _ready() -> void:
	instance = self
	layer = 20   # above Hud/menus — see UiRoot if this ever needs reordering
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func is_active() -> bool:
	return visible

## `node` is the conversation's first line. No-op if a conversation is
## already running — NPC._can_talk() already guards against this, but
## double-starting here would orphan whatever conversation was in progress.
func start(node: DialogueNode) -> void:
	if visible or node == null:
		return
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player:
		_player.enter_cinematic()
	visible = true
	Events.dialogue_started.emit()
	_show_node(node)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel_menu"):
		# Bail out early, same "Esc always gets you out" convention MenuBase
		# uses — regardless of whether a choice is currently showing.
		_end()
		return
	if _choice_list.get_children().is_empty() and event.is_action_pressed(&"interact"):
		_show_node(_current.next if _current else null)

func _show_node(node: DialogueNode) -> void:
	_current = node
	if node == null:
		_end()
		return
	if node.sets_flag != &"":
		Game.set_flag(node.sets_flag)
	_speaker_label.text = node.speaker
	_speaker_label.visible = node.speaker != ""
	_text_label.text = node.text
	_portrait_rect.texture = node.portrait
	_portrait_rect.visible = node.portrait != null

	for c in _choice_list.get_children():
		c.queue_free()
	var shown: Array[DialogueChoice] = []
	for choice in node.choices:
		if choice.is_visible():
			shown.append(choice)
	_choice_list.visible = not shown.is_empty()
	_continue_hint.visible = shown.is_empty()
	var first_button: Button
	for choice in shown:
		var b := Button.new()
		b.text = choice.text
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_pick.bind(choice))
		_choice_list.add_child(b)
		if first_button == null:
			first_button = b
	if first_button:
		# Lets ui_up/ui_down (arrow keys, Godot's own default — not WASD, so
		# this doesn't fight the game's own movement bindings) step through
		# the choices, and ui_accept (Enter/Space) pick whichever is
		# focused — Control's built-in focus/activation behavior, no extra
		# input handling needed here beyond actually grabbing focus somewhere
		# to start from.
		first_button.grab_focus()

func _pick(choice: DialogueChoice) -> void:
	if choice.sets_flag != &"":
		Game.set_flag(choice.sets_flag)
	_show_node(choice.next)

func _end() -> void:
	visible = false
	_current = null
	if _player:
		_player.machine.transition_to(&"Ground")
		_player = null
	Events.dialogue_ended.emit()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 80
	_panel.offset_right = -80
	_panel.offset_top = -220
	_panel.offset_bottom = -40
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(96, 96)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait_rect.visible = false
	hbox.add_child(_portrait_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(0, 72)
	_text_label.add_theme_font_size_override("normal_font_size", 18)
	vbox.add_child(_text_label)

	_continue_hint = Label.new()
	_continue_hint.text = "Press E to continue — Esc to leave"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.modulate = Color(1.0, 1.0, 1.0, 0.6)
	vbox.add_child(_continue_hint)

	_choice_list = VBoxContainer.new()
	vbox.add_child(_choice_list)
