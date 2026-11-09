class_name CombatTutorial
extends Node
## The two first-fight tutorial cards (shown once each, see TutorialPopup):
##   1. as the first fight begins: "Touch the orbs to build combo"
##   2. right after the first orb is hit: "Touch the ground to release the damages"
## Pure listener on Events — it never touches the arena. To add a step, add a
## STEPS-style handler below that emits Events.tutorial_popup_requested.
## Keyless cards (no `action`) are closed with the interact key.

const START_DELAY := 0.8   ## let the barrier rise before the first card

func _ready() -> void:
	Events.encounter_started.connect(_on_encounter_started)
	Events.orb_hit.connect(_on_orb_hit)

func _on_encounter_started(_arena: Node) -> void:
	if Game.flag(&"tutorial_combat_orbs"):
		return
	await get_tree().create_timer(START_DELAY).timeout
	_card(&"combat_orbs", "Touch the orbs to build combo")

func _on_orb_hit(_combo: int, _damage: float) -> void:
	_card(&"combat_release", "Touch the ground to release the damages")

func _card(id: StringName, text: String) -> void:
	Events.tutorial_popup_requested.emit(id, [{"action": &"", "tag": "", "text": text}])
