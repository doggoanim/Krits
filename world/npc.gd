class_name NPC
extends StaticBody3D
## A talkable world actor: shows a floating prompt while the player is in
## range and able to talk, and opens DialogueBox on `dialogue` when they
## press interact. Build it like WorldEnemy — give it a CollisionShape3D for
## its physical body (so the player can't walk through it) and whatever
## visual you want (a model, a placeholder mesh) as children; this script
## only owns the interaction range/prompt/trigger, nothing visual.

@export var dialogue: DialogueNode
@export var interact_radius := 2.5
@export var prompt_text := "Press E"
@export var prompt_height := 2.0   ## how far above this node's origin the floating prompt sits

var _player: Player
var _in_range := false
var _area: Area3D
var _prompt: Label3D

func _ready() -> void:
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1 << 1   # layer 2: player — see Player's own collision_layer
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interact_radius
	shape.shape = sphere
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	_prompt = Label3D.new()
	_prompt.text = prompt_text
	_prompt.position.y = prompt_height
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.visible = false
	add_child(_prompt)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body
		_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_in_range = false
		_player = null

func _process(_delta: float) -> void:
	var can_talk := _in_range and _can_talk()
	_prompt.visible = can_talk
	if can_talk and Input.is_action_just_pressed(&"interact"):
		_talk()

## Grounded (not mid-air/rolling/diving/etc.), alive, and nothing else
## already has a conversation open — same spirit as the checks other
## triggered moves make before taking over (e.g. WallClimbState's regrab
## cooldown), just gating a talk instead of a move.
func _can_talk() -> bool:
	return (dialogue != null and _player != null and not _player.dead
		and _player.machine.current_name == &"Ground"
		and DialogueBox.instance != null and not DialogueBox.instance.is_active())

func _talk() -> void:
	_player.face(global_position - _player.global_position)
	DialogueBox.instance.start(dialogue)
