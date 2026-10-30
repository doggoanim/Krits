class_name QuestTrigger
extends Area3D
## A place the player can "reach" for a REACH quest objective. Drop it in a
## level, give it a CollisionShape3D (any size) and a `place_id`; the first time
## the player walks in it sets the `reached_<place_id>` story flag (saved, so it
## stays reached). `notice` optionally pops a short HUD message.

@export var place_id: StringName = &""
@export var notice := ""   ## e.g. "Entered the Dry Plains" — leave empty for silent

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1   # the player's layer — same as Interactable's detection
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if place_id == &"" or not body is Player:
		return
	var flag := StringName("reached_" + String(place_id))
	if Game.flag(flag):
		return
	Game.set_flag(flag)
	if notice != "":
		Events.notice.emit(notice)
