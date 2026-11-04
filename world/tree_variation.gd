class_name TreeVariation
extends Node
## Gives every tree under its parent its own slightly different, deeper leaf
## colour, so a forest of identical imported models doesn't read as copy-paste.
##
## Drop this in as a child of the node that holds the trees (Props/Trees in
## chesburg.tscn). For each child prop it adds a FoliageWind (which already
## knows how to re-skin an imported model's materials) with sway turned off and
## a per-tree `green_tint` — the tint only touches green texels, so trunks keep
## their brown. The random pick is seeded from the tree's position, so a tree
## always has the same colour from run to run, and editing the level doesn't
## reshuffle the others.

## Baseline for every tree: a deeper, cooler green than the raw model.
@export var base_tint := Color(0.55, 0.78, 0.66)
## How far each tree may stray from the baseline, per channel
## (red = yellower/bluer, green = lighter/darker, blue = cooler/warmer).
@export var variation := Vector3(0.22, 0.14, 0.16)
## Nodes in the parent whose name contains one of these get tinted
## (everything else — rocks, stumps, particle nodes — is left alone).
@export var name_filter: PackedStringArray = ["tree"]
## Seeds the position hash; change it to reshuffle every tree's colour.
@export var seed_offset := 0

func _ready() -> void:
	var holder := get_parent()
	if holder == null:
		return
	for tree in holder.get_children():
		if tree is Node3D and _matches(tree.name):
			_tint(tree as Node3D)

func _matches(node_name: String) -> bool:
	for f in name_filter:
		if node_name.containsn(f):
			return true
	return false

func _tint(tree: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	var p := tree.global_position
	rng.seed = hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0))) + seed_offset
	var wind := FoliageWind.new()
	wind.name = "LeafTint"
	wind.wind_strength = 0.0
	wind.react_to_gusts = false
	wind.green_tint = Color(
		clampf(base_tint.r + rng.randf_range(-variation.x, variation.x), 0.0, 1.5),
		clampf(base_tint.g + rng.randf_range(-variation.y, variation.y), 0.0, 1.5),
		clampf(base_tint.b + rng.randf_range(-variation.z, variation.z), 0.0, 1.5))
	tree.add_child(wind)
