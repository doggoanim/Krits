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
## What the prompt says. Only the action word is shown, beside the interact
## key's button ("Press E to enter" -> "Enter"; plain "Press E" -> just the
## key) — see InteractPrompt. Any leading "Press <key> (to)" is dropped.
@export var prompt_text := "Press E"
@export var prompt_height := 2.0   ## how far above this node's origin the prompt sits

## Every Interactable the player can use right now (in range + _can_interact()).
## When several overlap only the nearest one shows its prompt and answers the
## interact key, so two neighbouring prompts never fight over one press.
static var _usable: Array[Interactable] = []

var player: Player
var _in_range := false
var _area: Area3D
var _verb := ""
var _prompting := false

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

	_verb = _verb_from(prompt_text)

func _exit_tree() -> void:
	_usable.erase(self)
	InteractPrompt.release(self)

## "Press E to enter" -> "Enter"; "Press E" -> "".
static func _verb_from(text: String) -> String:
	var re := RegEx.create_from_string("(?i)^\\s*press\\s+\\S+\\s*(to\\s+)?")
	var verb := re.sub(text, "").strip_edges()
	return verb.substr(0, 1).to_upper() + verb.substr(1)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player = body
		_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body == player:
		_in_range = false
		player = null

func _process(_delta: float) -> void:
	var can_use := _in_range and _can_interact()
	if can_use and not _usable.has(self):
		_usable.append(self)
	elif not can_use:
		_usable.erase(self)
	var usable := can_use and _nearest_usable() == self
	if usable:
		InteractPrompt.request(self, global_position + Vector3.UP * prompt_height, _verb)
	elif _prompting:
		InteractPrompt.release(self)
	_prompting = usable
	if usable and Input.is_action_just_pressed(&"interact"):
		_interact()

## The closest usable Interactable to the player (ties: whichever registered first).
func _nearest_usable() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for other in _usable:
		if not is_instance_valid(other) or other.player == null:
			continue
		var d := other.global_position.distance_squared_to(other.player.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best

## Overridden by subclasses to add their own gating (NPC: grounded, alive,
## no dialogue already open; ShopKeeper: no menu already open). True here
## just means "in range" — already guaranteed by the time this is called.
func _can_interact() -> bool:
	return true

## Overridden by subclasses — what actually happens on interact.
func _interact() -> void:
	pass
