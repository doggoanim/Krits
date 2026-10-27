class_name FoliageWind
extends Node
## Drop this in as a CHILD of any world prop you want swaying in the wind —
## a tree, a grass clump, a bush, anything with MeshInstance3Ds underneath
## it (see world/hometown.tscn's Props/Trees and Props/eyecandies for the
## props this is meant for). On ready, it rewrites every mesh surface under
## its own parent to shading/foliage_wind.gdshader, copying across that
## surface's existing look (albedo texture/color, vertex-color flag,
## roughness, metallic) so nothing changes visually except the sway itself.
##
## Why a sibling-of-the-mesh node instead of a script on the prop: every
## tree/grass asset here is an unmodified imported .glb instance with no
## script of its own (see world/hometown.tscn) — adding this as a plain
## child node opts a prop into wind sway with zero changes to the asset,
## the same "bolt it on" idiom as OutlineSystem/PixelateEffect elsewhere in
## this project. It's a real scene node (unlike those two), so its tunables
## below are directly editable per-instance in the Inspector — no push-down-
## from-Main indirection needed.
##
## wind_strength is world units of sway per world unit of the mesh's own
## local height — see the shader's header comment for why that scaling needs
## no per-asset calibration. The defaults read as a gentle grass flutter;
## bump wind_strength down for a prop that reads as too wild (a tall tree's
## crown sways further for the same value, being further from its root).

const SHADER := preload("res://shading/foliage_wind.gdshader")

@export var wind_strength := 0.06
@export var wind_speed := 1.5
@export var wind_scale := 0.3

func _ready() -> void:
	var parent := get_parent()
	if parent:
		_apply_recursive(parent)

func _apply_recursive(n: Node) -> void:
	if n is MeshInstance3D:
		_wind_ify(n as MeshInstance3D)
	for c in n.get_children():
		if c != self:
			_apply_recursive(c)

func _wind_ify(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count() if mi.mesh else 0:
		var src := mi.get_active_material(i)
		var wind_mat := ShaderMaterial.new()
		wind_mat.shader = SHADER

		# Same "copy the look across" approach as ModelUtil._shade_recursive()
		# (core/model_util.gd), just targeting plain imported materials
		# instead of toon-shaded character ones — an untextured/non-
		# BaseMaterial3D surface falls back to white rather than leaving the
		# sampler unbound, which Godot reads back as solid black.
		var tex := ModelUtil.white_texture()
		var tint := Color.WHITE
		var use_vertex_color := false
		var roughness := 1.0
		var metallic := 0.0
		var alpha_scissor := 0.0
		if src is BaseMaterial3D:
			var base := src as BaseMaterial3D
			tex = base.albedo_texture if base.albedo_texture else ModelUtil.white_texture()
			tint = base.albedo_color
			use_vertex_color = base.vertex_color_use_as_albedo
			roughness = base.roughness
			metallic = base.metallic
			if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				alpha_scissor = base.alpha_scissor_threshold

		wind_mat.set_shader_parameter(&"albedo_texture", tex)
		wind_mat.set_shader_parameter(&"albedo_color", tint)
		wind_mat.set_shader_parameter(&"use_vertex_color", use_vertex_color)
		wind_mat.set_shader_parameter(&"roughness", roughness)
		wind_mat.set_shader_parameter(&"metallic", metallic)
		wind_mat.set_shader_parameter(&"alpha_scissor_threshold", alpha_scissor)
		wind_mat.set_shader_parameter(&"wind_strength", wind_strength)
		wind_mat.set_shader_parameter(&"wind_speed", wind_speed)
		wind_mat.set_shader_parameter(&"wind_scale", wind_scale)
		mi.set_surface_override_material(i, wind_mat)
