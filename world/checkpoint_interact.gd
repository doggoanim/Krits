class_name CheckpointInteract
extends Interactable
## The "[E]" prompt over a checkpoint: press interact while standing at it to
## open the fast travel screen. Lives as a child of Spawnpoint, which only adds
## it — the range/prompt/priority plumbing is Interactable's. Not a physical
## body: it shouldn't block the player or anything else.

func _init() -> void:
	prompt_text = "Press E to travel"
	prompt_height = 3.0
	interact_radius = Spawnpoint.TRIGGER_RADIUS   # inside the checkpoint area, so TravelMenu.can_open() agrees
	collision_layer = 0
	collision_mask = 0

func _can_interact() -> bool:
	return (player != null and not player.dead
		and not Game.in_combat
		and player.machine.current_name == &"Ground"
		and MenuBase.open_menu == null
		and (DialogueBox.instance == null or not DialogueBox.instance.is_active()))

func _interact() -> void:
	if TravelMenu.instance != null:
		TravelMenu.instance.open()
