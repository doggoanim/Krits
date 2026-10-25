class_name ModelUtil
extends RefCounted
## Shared helpers for loading a rigged glTF character model consistently
## across the game. PlayerVisual and EnemyVisual both call these, so the
## player and every animated enemy get the same treatment: auto-scaled to a
## target height regardless of export units, cel-shaded (shading/toon.gdshader
## — banded lighting *and* a hard-edged shadow, not just the built-in
## DIFFUSE_TOON render mode, which bands the lighting but leaves the shadow
## itself soft — see that shader's own header comment for why), and outlined
## — one place to change if that look ever changes.

const CEL_SHADER := preload("res://shading/toon.gdshader")

## Scales `model` uniformly so its current rest-pose bounding-box height
## matches `target_height`. Returns the AABB measured *before* scaling, so
## callers can size other things (like outline thickness) proportionally to
## the model regardless of what units it was originally exported in.
static func fit_height(model: Node3D, target_height: float) -> AABB:
	var box := AABB()
	var has_box := false
	var r := _accumulate_aabb(model, Transform3D.IDENTITY, box, has_box)
	box = r[0]
	has_box = r[1]
	if has_box and box.size.y > 0.001:
		model.scale = Vector3.ONE * (target_height / box.size.y)
	return box

static func _accumulate_aabb(n: Node, parent_xform: Transform3D, box: AABB, has_box: bool) -> Array:
	var xform := parent_xform
	if n is Node3D:
		xform = parent_xform * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b: AABB = xform * (n as MeshInstance3D).mesh.get_aabb()
		box = box.merge(b) if has_box else b
		has_box = true
	for c in n.get_children():
		var r := _accumulate_aabb(c, xform, box, has_box)
		box = r[0]
		has_box = r[1]
	return [box, has_box]

## Sets every mesh surface under `model` to the game's shared cel-shaded look
## (shading/toon.gdshader — see CEL_SHADER above) and gives it a black
## inverted-hull outline `outline_thickness` thick (see CelOutline). Appends
## every new ShaderMaterial to `out_materials` if given, so a caller
## (flash-on-hit, slime tinting, ...) can modify them later without
## re-walking the tree — use get_tint()/set_tint() below rather than poking
## the shader parameter directly, so callers don't need to know its name.
static func apply_cel_shading(model: Node3D, outline_thickness: float,
		outline_color := Color.BLACK, out_materials: Array = []) -> void:
	_shade_recursive(model, outline_thickness, outline_color, out_materials)

static func _shade_recursive(n: Node, outline_thickness: float, outline_color: Color,
		out_materials: Array) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count() if mi.mesh else 0:
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var base := mat as BaseMaterial3D
				var cel := ShaderMaterial.new()
				cel.shader = CEL_SHADER
				cel.set_shader_parameter(&"albedo_texture", base.albedo_texture)
				cel.set_shader_parameter(&"albedo_color", base.albedo_color)
				mi.set_surface_override_material(i, cel)
				out_materials.append(cel)
		if outline_thickness > 0.0:
			CelOutline.apply(mi, outline_thickness, outline_color)
	for c in n.get_children():
		_shade_recursive(c, outline_thickness, outline_color, out_materials)

## Thin wrappers around the cel material's tint parameter, so flash-on-hit,
## slime tinting etc. don't need to know shading/toon.gdshader's parameter
## name or that it's a shader at all.
static func get_tint(material: ShaderMaterial) -> Color:
	return material.get_shader_parameter(&"albedo_color")

static func set_tint(material: ShaderMaterial, color: Color) -> void:
	material.set_shader_parameter(&"albedo_color", color)
