class_name WaterVolume
extends Area3D
## Detects the player entering/exiting a body of water and triggers a splash
## at the waterline (see PlayerEffects.burst_water_splash()) — purely a
## visual trigger, no swim mechanics of its own (speed change, buoyancy,
## drowning, ...). None of that was asked for; add it separately if it ever
## is, this node only owns the splash.
##
## Drop one of these as a sibling of a water mesh (world/water/water.tscn or
## the hometown.tscn lake), sized to its surface via `size`, and set
## `surface_y` to wherever the water's actual top sits relative to THIS
## node's own origin — not necessarily its center, since the box is usually
## easier to position a bit below the surface so a player walking in is
## already "inside" a little before the splash fires, rather than right at
## the literal edge.

@export var size := Vector3(10.0, 4.0, 10.0)
@export var surface_y := 0.0   ## local Y of the water's top surface, relative to this node's own origin

var _player_inside := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1   # layer 2: player — see Player.collision_layer
	monitorable = false

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	add_child(cs)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is Player and not _player_inside:
		_player_inside = true
		(body as Player).effects.burst_water_splash(_waterline_pos(body), true)

func _on_body_exited(body: Node3D) -> void:
	if body is Player and _player_inside:
		_player_inside = false
		(body as Player).effects.burst_water_splash(_waterline_pos(body), false)

## The splash plays at the player's horizontal position but the water's own
## surface height — not the player's current Y, which on entry is usually
## still above the surface (the body/area overlap a little before the feet
## are actually underwater) and on exit is wherever they climbed out to.
func _waterline_pos(body: Node3D) -> Vector3:
	return Vector3(body.global_position.x, global_position.y + surface_y, body.global_position.z)
