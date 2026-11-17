class_name HouseVariation
extends Node
## Stops a town of copy-pasted houses reading as copy-paste: every house under its
## parent gets its own wall colour and roof colour. Like TreeVariation it needs no
## changes to the imported models: drop it in as a child of the node that holds the
## houses (Buildings in chesburg.tscn) and it gives each house its own copies of the
## "wall" and "roof" materials, tinted from the palettes below.
##
## Picks are deterministic (house order, then a small hash of its position for a
## slight shade difference), so a house keeps its colours from run to run, and the
## step through the palettes is chosen so neighbouring houses rarely match.

## Tints multiplied into the wall texture. White keeps the original look.
@export var wall_tints: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.93, 0.8),    # cream
	Color(0.82, 0.9, 1.0),    # pale blue
	Color(0.88, 1.0, 0.86),   # mint
	Color(1.0, 0.85, 0.85),   # rose
	Color(1.0, 0.97, 0.68),   # butter
]
## Tints multiplied into the roof texture.
@export var roof_tints: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.68, 0.58),   # terracotta
	Color(0.66, 0.76, 1.0),   # slate blue
	Color(0.72, 0.92, 0.66),  # moss
	Color(0.85, 0.66, 0.5),   # brown
]
## Each house moves this many steps along the palette from the previous one (coprime
## with the palette sizes, so every colour gets used before any repeats).
@export var wall_step := 5
@export var roof_step := 3
## Houses to recolour: nodes in the parent whose name contains one of these.
@export var name_filter: PackedStringArray = ["house_chesburg"]
## How much each house's shade may wander either way (0 = exactly the palette colour).
@export var shade_jitter := 0.05
## Shifts the whole assignment; change it to reshuffle every house.
@export var seed_offset := 0

func _ready() -> void:
	var holder := get_parent()
	if holder == null:
		return
	var index := 0
	for child in holder.get_children():
		if child is Node3D and _matches(child.name):
			_colour(child as Node3D, index)
			index += 1

func _matches(node_name: String) -> bool:
	for f in name_filter:
		if node_name.containsn(f):
			return true
	return false

func _colour(house: Node3D, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	var p := house.global_position
	rng.seed = hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0))) + seed_offset
	var wall := _jitter(wall_tints[(index * wall_step + seed_offset) % wall_tints.size()], rng)
	var roof := _jitter(roof_tints[(index * roof_step + 1 + seed_offset) % roof_tints.size()], rng)
	_apply(house, wall, roof)

func _jitter(c: Color, rng: RandomNumberGenerator) -> Color:
	var j := rng.randf_range(-shade_jitter, shade_jitter)
	return Color(clampf(c.r + j, 0.0, 1.0), clampf(c.g + j, 0.0, 1.0), clampf(c.b + j, 0.0, 1.0), c.a)

func _apply(n: Node, wall: Color, roof: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null:
				continue
			var label := (src.resource_name + " " + String(mi.mesh.surface_get_material(i).resource_name if mi.mesh.surface_get_material(i) else "")).to_lower()
			var tint := Color.WHITE
			if label.contains("wall"):
				tint = wall
			elif label.contains("roof"):
				tint = roof
			else:
				continue
			var copy := src.duplicate() as BaseMaterial3D   # its own copy: the other houses keep theirs
			copy.albedo_color = src.albedo_color * tint
			mi.set_surface_override_material(i, copy)
	for c in n.get_children():
		_apply(c, wall, roof)
