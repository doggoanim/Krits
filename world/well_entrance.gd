class_name WellEntrance
extends Area3D
## The hollow middle of a well: when the player jumps in, they drop into
## another level (see Door for the mechanics of a level swap). A plain trigger
## volume rather than an Interactable: there's no prompt, the jump itself is
## the input. Give it a CollisionShape3D that fills the hollow below the rim.

@export_file("*.tscn") var target_level: String
@export var target_spawn_id: StringName = &"well_drop"

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1   # layer 2: the player
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if target_level.is_empty() or not body is Player:
		return
	var player := body as Player
	if player.dead or Game.input_locked or Game.in_combat:
		return
	Events.level_travel_requested.emit(load(target_level) as PackedScene, target_spawn_id)
