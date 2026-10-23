class_name Interactable
extends StaticBody3D
## Shared "show a floating prompt while the player's in range and able to
## use this, press interact to trigger it" behavior — factored out of NPC
## once ShopKeeper needed the exact same range/prompt/trigger plumbing with
## different content. Build it like WorldEnemy/NPC: give it a
## CollisionShape3D for its physical body (so the player can't walk through
## it) and whatever visual you want as children; this script only owns the
## interaction range/prompt/trigger, nothing visual.
##
## Subclasses override _can_interact() (gate it further — NPC also checks
## the player's grounded/alive/no-other-conversation-open, for instance) and
## _interact() (what actually happens).

@export var interact_radius := 2.5
@export var prompt_text := "Press E"
@export var prompt_height := 2.0   ## how far above this node's origin the floating prompt sits

var player: Player
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
		player = body
		_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body == player:
		_in_range = false
		player = null

func _process(_delta: float) -> void:
	var usable := _in_range and _can_interact()
	_prompt.visible = usable
	if usable and Input.is_action_just_pressed(&"interact"):
		_interact()

## Overridden by subclasses to add their own gating (NPC: grounded, alive,
## no dialogue already open; ShopKeeper: no menu already open). True here
## just means "in range" — already guaranteed by the time this is called.
func _can_interact() -> bool:
	return true

## Overridden by subclasses — what actually happens on interact.
func _interact() -> void:
	pass
