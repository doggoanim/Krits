@tool
class_name ClothSway
extends Node
## Bolt-on: add as a child of any prop built with shading/cloth_wind.gdshader
## (laundry, bunting, stall cloth) and every cloth material under its parent
## gets the current gust from WindGusts each frame, so it flutters harder when a
## gust sweeps through, in step with the grass, signs and chimes.

var _materials: Array[ShaderMaterial] = []
var _anchor: Node3D

func _ready() -> void:
	_anchor = get_parent() as Node3D
	if _anchor == null:
		set_process(false)
		return
	for m in _anchor.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_override as ShaderMaterial
		if mat != null and mat.shader == HouseProps.CLOTH:
			_materials.append(mat)
	set_process(not _materials.is_empty())

func _process(_delta: float) -> void:
	if not _anchor.is_inside_tree():
		return
	var p := _anchor.global_position
	var gust := WindGusts.sample(Vector2(p.x, p.z), Time.get_ticks_msec() / 1000.0)
	for mat in _materials:
		mat.set_shader_parameter(&"gust", gust)
