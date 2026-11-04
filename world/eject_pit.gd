class_name EjectPit
extends Area3D
## A pit at the bottom of a level: fall into it and you are hurt a little, then
## thrown out of the level to `target_spawn_id` in `target_level` (for the well:
## back out into Chesburg, popped up into the air and away from the well mouth).
##
## It works like a Door travel (same Events.level_travel_requested swap behind
## the iris), plus a launch: the velocity in `launch_velocity` is stored in
## Game.arrival_velocity and Main applies it right after placing the player.
## If the damage kills the player, the normal death sequence runs instead.
##
## The trigger box is built from `size` here, so you only need to position the
## node (below the lowest floor) and size it to cover the whole level.

@export_file("*.tscn") var target_level := "res://world/chesburg.tscn"
@export var target_spawn_id: StringName = &"well_exit"
@export var damage := 10.0
## World-space velocity the player arrives with (up, and away from the well mouth).
@export var launch_velocity := Vector3(0.0, 12.0, 5.0)
@export var size := Vector3(120.0, 4.0, 140.0)

var _busy := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1   # the player's physics layer
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or _busy or player.dead or target_level.is_empty():
		return
	_busy = true
	if damage > 0.0:
		player.hit(damage, true)   # no 'from': a fall has no direction to be shoved from
	if player.dead:
		_busy = false              # the death sequence takes over
		return
	Game.arrival_velocity = launch_velocity
	Events.level_travel_requested.emit(load(target_level) as PackedScene, target_spawn_id)
