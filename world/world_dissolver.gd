class_name WorldDissolver
extends RefCounted
## Dissolves every MeshInstance3D under a root node using a world-space blocky noise
## shader (world_dissolve.gdshader), so the level geometry itself crumbles into noise
## and reforms, instead of a screen overlay fading over it.
##
## Usage:
##   var d := WorldDissolver.new()
##   d.begin(world_root)        # swaps in the dissolve shader; progress starts at 0
##   d.set_progress(1.0)        # jump or tween this toward 1.0 to dissolve away
##   d.finish()                 # restores every mesh's original material
##
## One dissolver drives one shared ShaderMaterial, so everything it targets dissolves
## in lockstep off the same noise field; each mesh keeps its own color via a per-
## instance shader parameter. Keep separate WorldDissolver instances for separate
## things that should animate independently (e.g. the overworld vs. the arena stage).

const SHADER := preload("res://world/world_dissolve.gdshader")

var progress := 0.0

var _material := ShaderMaterial.new()
var _instances: Array[MeshInstance3D] = []
var _originals: Dictionary = {}   # MeshInstance3D -> Material (original override, may be null)

func _init() -> void:
	_material.shader = SHADER

## Swaps in the shared dissolve material on every MeshInstance3D under `root`.
## Safe to call again later to re-target the same dissolver at a new root.
func begin(root: Node3D) -> void:
	_instances.clear()
	_originals.clear()
	_collect(root)
	for mi in _instances:
		_originals[mi] = mi.material_override
		mi.set_instance_shader_parameter(&"albedo_color", _extract_albedo(mi))
		mi.material_override = _material
	set_progress(0.0)

## 0.0 = fully visible (as the original materials), 1.0 = fully dissolved away.
func set_progress(v: float) -> void:
	progress = v
	_material.set_shader_parameter(&"progress", v)

## Restores every mesh's original material and forgets the current target.
func finish() -> void:
	for mi in _instances:
		if is_instance_valid(mi):
			mi.material_override = _originals.get(mi)
	_instances.clear()
	_originals.clear()

func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		_instances.append(n)
	for c in n.get_children():
		_collect(c)

func _extract_albedo(mi: MeshInstance3D) -> Color:
	var mat := mi.material_override
	if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		mat = mi.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_color
	return Color(1.0, 1.0, 1.0)
