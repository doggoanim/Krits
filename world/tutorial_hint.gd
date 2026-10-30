class_name TutorialHint
extends Node3D
## A wordless "do this" hint: while the player stands inside its box it shows
## the key(s) for `actions` (several cycle in order, e.g. Shift → Space for a
## long jump) over the obstacle, and disappears for good the first time the
## player enters one of `done_states` while inside it. "Done" is remembered
## as the story flag `tutorial_<hint_id>`, so it also stays gone after a
## reload. Place it before the obstacle that needs the move, size the box to
## the approach, and tune `prompt_height` so the key floats where it's seen.
##
## Player states are the ids registered in Player (Ground, Air, Crouch, Roll,
## LongJump, Dive, Pound, PoundLand, WallClimb, Swim, ...).

@export var hint_id: StringName
@export var actions: Array[StringName] = [&"jump"]
@export var done_states: Array[StringName] = []
@export var size := Vector3(4, 3, 4)
@export var prompt_height := 2.2

var _player: Player
var _prompting := false

func _ready() -> void:
	if Game.flag(_flag()):
		set_process(false)
		return
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1 << 1   # layer 2: the player
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _exit_tree() -> void:
	InteractPrompt.release(self)

func _flag() -> StringName:
	return StringName("tutorial_%s" % hint_id)

func _on_body_entered(body: Node3D) -> void:
	if body is Player and _player == null:
		_player = body
		_player.machine.state_changed.connect(_on_state_changed)

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_leave()

func _leave() -> void:
	if _player != null and is_instance_valid(_player):
		if _player.machine.state_changed.is_connected(_on_state_changed):
			_player.machine.state_changed.disconnect(_on_state_changed)
	_player = null

func _on_state_changed(_prev: StringName, next: StringName) -> void:
	if next in done_states:
		Game.set_flag(_flag())
		_leave()
		InteractPrompt.release(self)
		set_process(false)

func _process(_delta: float) -> void:
	var show_it := _player != null and not _player.dead and not Game.input_locked \
		and not Game.in_combat
	if show_it:
		InteractPrompt.request(self, global_position + Vector3.UP * prompt_height, "", actions)
	elif _prompting:
		InteractPrompt.release(self)
	_prompting = show_it
