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

## Grounded (not mid-air/rolling/diving/etc.), alive, and nothing else
## already has a conversation open — same spirit as the checks other
## triggered moves make before taking over (e.g. WallClimbState's regrab
## cooldown), just gating a talk instead of a move.
func _can_interact() -> bool:
	return (dialogue != null and player != null and not player.dead
		and player.machine.current_name == &"Ground"
		and DialogueBox.instance != null and not DialogueBox.instance.is_active())

func _interact() -> void:
	player.face(global_position - player.global_position)
	DialogueBox.instance.start(dialogue)
