class_name InteractPrompt
extends Control
## The "press the interact key" prompt shown over whatever the player can use
## (doors, NPCs, shops). Screen-space UI rather than a 3D label, so it can use
## the same hand-drawn button art as the menus: a button plate showing just the
## interact key's letter — stretched at its two ends to fit however wide the
## label is ("E", "Shift", "Space") — with the action word beside it.
##
## Each time the prompt appears it picks one of the three button drawings at
## random (plate_styles), pops in, and follows the object it belongs to. One
## shared instance (owned by UiRoot); Interactables call request()/release()
## rather than owning any UI themselves.

static var instance: InteractPrompt

const ACTION := &"interact"
const POP_TIME := 0.16
const PROMPT_SCALE := 0.5   ## whole prompt drawn at this fraction of its authored size
const CYCLE_TIME := 0.9   ## seconds each key shows when a prompt lists several actions

## The three plate looks to pick between — StyleBoxTextures of button_1/2/3,
## nine-sliced (see interact_prompt.tscn) so the plate can grow around the key.
@export var plate_styles: Array[StyleBox] = []

@onready var _box: HBoxContainer = %Box
@onready var _plate: PanelContainer = %Plate
@onready var _key: Label = %Key
@onready var _verb: Label = %Verb

var _scroll_hint: Label   ## "^ 1/2" badge, shown while several prompts overlap
var _owner: Object
var _world_pos := Vector3.ZERO
var _pop: Tween
var _actions: Array[StringName] = [ACTION]   ## input actions shown; several = cycled in order
var _cycle_t := 0.0
var _cycle_i := 0

func _ready() -> void:
	instance = self
	_scroll_hint = _verb.duplicate() as Label
	_scroll_hint.add_theme_font_size_override(&"font_size", 34)
	_scroll_hint.visible = false
	_box.add_child(_scroll_hint)
	process_mode = Node.PROCESS_MODE_ALWAYS   # so it can hide itself while the game is paused
	visible = false

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Called every frame by an Interactable the player can currently use.
## `verb` is the action word shown beside the key ("" = key only).
## `actions` overrides which input action's key is shown (default: interact);
## give several and they cycle in order — a wordless "press A, then B" hint
## (see TutorialHint).
## `choices` > 1 means several prompts overlap: a "^ n/m" badge shows which
## one (`choice_index`) is selected out of how many.
static func request(for_owner: Object, world_pos: Vector3, verb: String,
		actions: Array[StringName] = [], choices := 1, choice_index := 0) -> void:
	if instance != null:
		instance._request(for_owner, world_pos, verb, actions, choices, choice_index)

## Called by an Interactable when it stops being usable.
static func release(for_owner: Object) -> void:
	if instance != null and instance._owner == for_owner:
		instance._owner = null

func _request(for_owner: Object, world_pos: Vector3, verb: String,
		actions: Array[StringName], choices: int, choice_index: int) -> void:
	_world_pos = world_pos
	_update_scroll_hint(choices, choice_index)
	if _owner == for_owner:
		return
	_owner = for_owner
	if actions.is_empty():
		_actions = [ACTION]
	else:
		_actions = actions
	_cycle_i = 0
	_cycle_t = 0.0
	_show(verb)

func _show(verb: String) -> void:
	if not plate_styles.is_empty():
		_plate.add_theme_stylebox_override(&"panel", plate_styles.pick_random())
	_key.text = _key_for(_actions[0])
	_verb.text = verb
	_verb.visible = verb != ""
	_box.reset_size()
	_box.pivot_offset = _box.get_combined_minimum_size() * 0.5
	_box.scale = Vector2.ONE * PROMPT_SCALE * 0.6
	if _pop and _pop.is_valid():
		_pop.kill()
	_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(_box, "scale", Vector2.ONE * PROMPT_SCALE, POP_TIME)

func _update_scroll_hint(choices: int, choice_index: int) -> void:
	var show_hint := choices > 1
	if show_hint:
		var text := "^ %d/%d" % [choice_index + 1, choices]
		if _scroll_hint.text != text:
			_scroll_hint.text = text
	if _scroll_hint.visible != show_hint:
		_scroll_hint.visible = show_hint
		_box.reset_size()

func _key_for(action: StringName) -> String:
	return InputSetup.key_label(Settings.get_binding(action))

func _process(delta: float) -> void:
	if _actions.size() > 1 and _owner != null:
		_cycle_t += delta
		if _cycle_t >= CYCLE_TIME:
			_cycle_t = 0.0
			_cycle_i = (_cycle_i + 1) % _actions.size()
			_key.text = _key_for(_actions[_cycle_i])
			_box.reset_size()
	var cam := get_viewport().get_camera_3d()
	var active := _owner != null and is_instance_valid(_owner) and not get_tree().paused \
			and cam != null and not cam.is_position_behind(_world_pos)
	visible = active
	if not active:
		if _owner != null and not is_instance_valid(_owner):
			_owner = null
		return
	_box.position = cam.unproject_position(_world_pos) - _box.size * 0.5
