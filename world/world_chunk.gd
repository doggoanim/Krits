class_name WorldChunk
extends Node3D
## Wraps a region of hand-placed content (geometry, props, decorations — anything
## that doesn't already self-cull like WorldEnemy does) and shows/hides it based
## on distance to the player, so one big interconnected map only pays rendering
## cost for the part actually nearby.
##
## Usage: in the editor, reparent a region's nodes under a WorldChunk instead of
## directly under the level root, and position the WorldChunk node itself near
## the center of that region (the distance check is measured from here).
## Everything about building the content underneath stays exactly the same —
## this only adds the distance check on top.
##
## Only toggles `visible`, deliberately not collision or process_mode: static
## colliders are already cheap for Godot's physics broad-phase to prune at
## distance, and disabling them risks a player falling through the floor
## mid-transition. If something under a chunk runs its own per-frame logic
## (an enemy, a moving platform), give it its own distance check too — see
## WorldEnemy's spawn_radius/despawn_radius for the pattern.

@export var view_distance := 80.0
@export var check_interval := 0.25   ## how often to re-check; doesn't need to be every frame

var _player: Player
var _t := 0.0

func _ready() -> void:
	visible = false
	# Stagger each chunk's first check so hundreds of them don't all land on
	# the exact same frame.
	_t = randf() * check_interval

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = check_interval
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	visible = global_position.distance_to(_player.global_position) <= view_distance
