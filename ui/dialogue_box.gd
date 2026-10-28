class_name DialogueBox
extends CanvasLayer
## The game's one conversation UI. Layout lives in ui/dialogue_box.tscn
## (hand-drawn plates, editable in the editor); this script only runs the
## conversation:
##
##   - walks a DialogueNode graph (see dialogue/dialogue_node.gd),
##   - types each line out with Typewriter (BBCode + [pause=s] tags),
##   - lets the player finish a line (interact), skip (hold interact),
##   - hands the in-world side (freeze player, camera focus, speaker turn)
##     to DialogueStage.
##
## Create it with DialogueBox.create() — never DialogueBox.new(), which
## would give an empty layer with no UI.
##
## Public API (unchanged for existing callers):
##   DialogueBox.instance            the live box (null before one exists)
##   start(node, speaker = null)     begin a conversation; `speaker` is the
##                                   Node3D to frame (optional)
##   is_active()                     true while a conversation is open

const SCENE_PATH := "res://ui/dialogue_box.tscn"
const SKIP_HOLD_TIME := 0.45     ## seconds interact must be held before it skips
const SKIP_TICK := 0.12          ## seconds between lines while skipping
const OPEN_TIME := 0.28
const CLOSE_TIME := 0.18

static var instance: DialogueBox

@export var plate_styles: Array[StyleBox] = []   ## one is picked at random per line

@onready var _root: Control = %Root
@onready var _plate: PanelContainer = %Plate
@onready var _name_tag: PanelContainer = %NameTag
@onready var _speaker_label: Label = %Speaker
@onready var _portrait: TextureRect = %Portrait
@onready var _text: RichTextLabel = %Text
@onready var _hint: Label = %Hint
@onready var _choices: VBoxContainer = %Choices
@onready var _typewriter: Typewriter = %Typewriter

var _open := false
var _current: DialogueNode
var _stage: DialogueStage
var _line_done := false
var _opened_frame := -1
var _holding := false
var _hold_time := 0.0
var _skip_tick := 0.0
var _tween: Tween

static func create() -> DialogueBox:
	return (load(SCENE_PATH) as PackedScene).instantiate() as DialogueBox

func _ready() -> void:
	instance = self
	visible = false
	_typewriter.finished.connect(_on_line_finished)
	for c in [_plate, _name_tag]:
		c.resized.connect(_center_pivot.bind(c))
		_center_pivot(c)
	Settings.changed.connect(_on_setting_changed)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func is_active() -> bool:
	return _open

## `node` is the conversation's first line; `speaker` (optional) is the 3D
## actor to frame and turn toward the player. No-op if one is already open.
func start(node: DialogueNode, speaker: Node3D = null) -> void:
	if _open or node == null:
		return
	_open = true
	_opened_frame = Engine.get_process_frames()
	_holding = false
	_stage = DialogueStage.new()
	_stage.begin(speaker, get_tree())
	visible = true
	_animate_open()
	Events.dialogue_started.emit()
	_show_node(node)

# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# The press that opened the conversation must not also advance it.
	if not _open or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"ui_cancel_menu"):
		_end()
	elif event.is_action_pressed(&"interact"):
		_holding = true
		_hold_time = 0.0
		_skip_tick = 0.0
		_press_interact()
	elif event.is_action_released(&"interact"):
		_holding = false
	else:
		return
	get_viewport().set_input_as_handled()

func _press_interact() -> void:
	if _typewriter.is_typing():
		_typewriter.finish()
	elif _line_done:
		var focused := get_viewport().gui_get_focus_owner()
		if _choices.get_child_count() > 0:
			if focused is Button and _choices.is_ancestor_of(focused):
				focused.pressed.emit()
		else:
			_advance()

func _process(delta: float) -> void:
	if not _open:
		return
	if _holding:
		_hold_time += delta
		if _hold_time >= SKIP_HOLD_TIME:
			_skip_tick -= delta
			if _skip_tick <= 0.0:
				_skip_tick = SKIP_TICK
				if _typewriter.is_typing():
					_typewriter.finish()
				elif _line_done and _choices.get_child_count() == 0:
					_advance()

func _skipping() -> bool:
	return _holding and _hold_time >= SKIP_HOLD_TIME

func _on_setting_changed(key: StringName) -> void:
	if key == &"controls/bindings":
		_refresh_hint()

# --- Conversation flow ------------------------------------------------------

func _advance() -> void:
	_show_node(_current.next if _current else null)

func _show_node(node: DialogueNode) -> void:
	_current = node
	if node == null:
		_end()
		return
	if node.sets_flag != &"":
		Game.set_flag(node.sets_flag)
	_line_done = false
	_clear_choices()
	_hint.visible = false
	_speaker_label.text = node.speaker
	_name_tag.visible = node.speaker != ""
	_portrait.texture = node.portrait
	_portrait.visible = node.portrait != null
	if not plate_styles.is_empty():
		_plate.add_theme_stylebox_override(&"panel", plate_styles.pick_random())
	_pop(_plate)
	if _name_tag.visible:
		_pop(_name_tag)
	_typewriter.speed = Settings.get_value(&"accessibility/text_speed")
	_typewriter.play(_text, node.text)
	if _skipping():
		_typewriter.finish()

func _on_line_finished() -> void:
	if not _open or _current == null:
		return
	_line_done = true
	var options := _current.visible_choices()
	if not options.is_empty():
		_show_choices(options)
		return
	_refresh_hint()
	_hint.visible = true

func _show_choices(options: Array[DialogueChoice]) -> void:
	for choice in options:
		var b := Button.new()
		b.text = choice.text
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_pick.bind(choice))
		_choices.add_child(b)
	FocusPop.attach_all(_choices)
	# Arrow keys and the (mirrored) movement keys move between choices through
	# Godot's own focus handling — see InputSetup.UI_MIRRORS.
	(_choices.get_child(0) as Button).grab_focus()
	_pop(_choices)

func _clear_choices() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()

func _pick(choice: DialogueChoice) -> void:
	if choice.sets_flag != &"":
		Game.set_flag(choice.sets_flag)
	_show_node(choice.next)

func _end() -> void:
	if not _open:
		return
	_open = false
	_current = null
	_holding = false
	_typewriter.finish()
	_clear_choices()
	if _stage:
		_stage.end()
		_stage = null
	_animate_close()
	Events.dialogue_ended.emit()

# --- Presentation -----------------------------------------------------------

func _refresh_hint() -> void:
	var key := InputSetup.key_label(Settings.get_binding(&"interact"))
	_hint.text = "%s  Next   ·   hold  Skip" % key

func _center_pivot(c: Control) -> void:
	c.pivot_offset = c.size * 0.5

## Small squash-in so each new plate feels placed rather than swapped.
func _pop(c: Control) -> void:
	c.scale = Vector2(0.96, 0.94)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(c, "scale", Vector2.ONE, 0.18)

func _animate_open() -> void:
	if _tween:
		_tween.kill()
	_root.position.y = 90.0
	_root.modulate.a = 0.0
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_root, "position:y", 0.0, OPEN_TIME)
	_tween.tween_property(_root, "modulate:a", 1.0, OPEN_TIME * 0.7)

func _animate_close() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_root, "position:y", 70.0, CLOSE_TIME)
	_tween.tween_property(_root, "modulate:a", 0.0, CLOSE_TIME)
	_tween.chain().tween_callback(func() -> void: visible = _open)
