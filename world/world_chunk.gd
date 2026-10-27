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
## Only toggles `visible`/transparency, deliberately not collision or
## process_mode: static colliders are already cheap for Godot's physics
## broad-phase to prune at distance, and disabling them risks a player
## falling through the floor mid-transition. If something under a chunk runs
## its own per-frame logic (an enemy, a moving platform), give it its own
## distance check too — see WorldEnemy's spawn_radius/despawn_radius for the
## pattern.
##
## Crossing view_distance cross-fades over fade_time instead of an instant
## visible toggle — walking along the edge of view_distance used to pop a
## whole region of the level in/out in a single frame, which reads as a
## glitch/LOD seam; fading it over a short window reads as the region simply
## being hazy/distant right up until it's gone. The fade is done by pushing a
## transparency override onto every GeometryInstance3D under this chunk
## (restored once fully visible again) rather than a screen overlay, so
## overlapping chunks each fade independently and correctly.

@export var view_distance := 80.0
@export var check_interval := 0.25   ## how often to re-check; doesn't need to be every frame
@export var fade_time := 0.4         ## seconds to cross-fade in/out once view_distance is crossed

var _player: Player
var _t := 0.0
var _alpha := 0.0
var _in_range := false
var _geo: Array[GeometryInstance3D] = []

func _ready() -> void:
	visible = false
	_collect(self)
	_set_alpha(0.0)
	# Stagger each chunk's first check so hundreds of them don't all land on
	# the exact same frame.
	_t = randf() * check_interval

func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = check_interval
		if _player == null:
			_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player != null:
			_in_range = global_position.distance_to(_player.global_position) <= view_distance

	if _alpha == 0.0 and not _in_range:
		return   # fully faded out and still out of range — nothing to update

	visible = true
	var target := 1.0 if _in_range else 0.0
	_set_alpha(move_toward(_alpha, target, delta / maxf(fade_time, 0.001)))
	if _alpha <= 0.0 and not _in_range:
		visible = false

func _collect(n: Node) -> void:
	if n is GeometryInstance3D:
		_geo.append(n)
	for c in n.get_children():
		_collect(c)

## transparency is Godot's own per-instance 0..1 fade knob (same thing
## GeometryInstance3D exposes in the Inspector) — cheap to drive directly
## without touching any material, and it composites correctly over however
## many separate materials a chunk's props actually use.
func _set_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)
	for g in _geo:
		if is_instance_valid(g):
			g.transparency = 1.0 - _alpha
