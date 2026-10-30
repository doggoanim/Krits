class_name NPC
extends Interactable
## A talkable world actor: shows a floating prompt while the player is in
## range and able to talk, and opens DialogueBox on `dialogue` when they
## press interact. Build it like WorldEnemy — give it a CollisionShape3D for
## its physical body (so the player can't walk through it) and whatever
## visual you want (a model, a placeholder mesh) as children; the range/
## prompt/trigger plumbing itself lives in Interactable (see there) — this
## just supplies what "usable" and "interact" mean for a conversation.

@export var dialogue: DialogueNode
## Say something different once a story flag is set; the first variant whose
## flag is set wins, otherwise `dialogue` is used. See DialogueVariant.
@export var variants: Array[DialogueVariant] = []
@export var head_height := 1.6          ## where the camera looks while talking
@export var face_player := true         ## turn toward the player during a conversation
@export var facing_offset := 0.0        ## radians; PI if the model's front is +Z instead of -Z

var _rest_yaw := 0.0
var _turn_tween: Tween

## Grounded (not mid-air/rolling/diving/etc.), alive, and nothing else
## already has a conversation open — same spirit as the checks other
## triggered moves make before taking over (e.g. WallClimbState's regrab
## cooldown), just gating a talk instead of a move.
func _can_interact() -> bool:
	return (_current_dialogue() != null and player != null and not player.dead
		and player.machine.current_name == &"Ground"
		and DialogueBox.instance != null and not DialogueBox.instance.is_active())

func _interact() -> void:
	DialogueBox.instance.start(_current_dialogue(), self)

func _current_dialogue() -> DialogueNode:
	for v in variants:
		if v != null and v.dialogue != null and v.required_flag != &"" and Game.flag(v.required_flag):
			return v.dialogue
	return dialogue

# --- DialogueStage speaker interface ------------------------------------

func get_focus_point() -> Vector3:
	return global_position + Vector3.UP * head_height

func face_toward(world_pos: Vector3) -> void:
	if not face_player:
		return
	var d := world_pos - global_position
	_rest_yaw = rotation.y
	_turn_to(atan2(-d.x, -d.z) + facing_offset)

func restore_facing() -> void:
	if face_player:
		_turn_to(_rest_yaw)

func _turn_to(yaw: float) -> void:
	if _turn_tween:
		_turn_tween.kill()
	_turn_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, yaw), 0.4)
