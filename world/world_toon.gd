class_name WorldToon
extends RefCounted
## Gives a level's static props (houses, terrain, fences, rocks, Cyclops blocks...)
## the same banded toon look the characters have (shading/toon.gdshader), by
## swapping each opaque StandardMaterial3D for a toon ShaderMaterial that copies
## its texture and colour. Called once by Main right after a level is instanced
## (see Main._apply_level_lighting), gated by EnvironmentConfig.toon_world.
##
## Left alone on purpose, so their own look survives:
##  - anything already using a ShaderMaterial (water, wind-swayed foliage, sky)
##  - shadow-only meshes (cloud shadows)
##  - transparent/blended, unshaded, emissive (glowing windows, crystals) and
##    triplanar materials
##  - meshes in the NO_TOON_GROUP, or with a surface override already set

const TOON_SHADER: Shader = preload("res://shading/toon.gdshader")
const TOON_SHADER_2SIDED: Shader = preload("res://shading/toon_double_sided.gdshader")
const NO_TOON_GROUP := &"no_toon"   ## add a mesh (or a parent of meshes) to this group to opt out

## Shared per source material: a house with 40 identical planks gets one toon
## material, not 40 — which also keeps the draw-call batching intact.
static func apply(root: Node) -> void:
	var cache: Dictionary = {}   # BaseMaterial3D -> ShaderMaterial
	for n in root.find_children("*", "MeshInstance3D", true, false):
		_convert(n as MeshInstance3D, cache)

static func _convert(mi: MeshInstance3D, cache: Dictionary) -> void:
	if mi.mesh == null or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return
	if _is_opted_out(mi):
		return
	for i in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(i) != null:
			continue
		var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
		if src == null or not _convertible(src):
			continue
		if not cache.has(src):
			cache[src] = _make_toon(src)
		mi.set_surface_override_material(i, cache[src] as ShaderMaterial)

static func _is_opted_out(n: Node) -> bool:
	var cur: Node = n
	while cur != null:
		if cur.is_in_group(NO_TOON_GROUP):
			return true
		cur = cur.get_parent()
	return false

static func _convertible(m: BaseMaterial3D) -> bool:
	if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or m.emission_enabled or m.uv1_triplanar:
		return false
	if m.cull_mode == BaseMaterial3D.CULL_FRONT:
		return false
	return m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			or m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR

static func _make_toon(src: BaseMaterial3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER_2SIDED if src.cull_mode == BaseMaterial3D.CULL_DISABLED else TOON_SHADER
	mat.set_shader_parameter(&"rim_strength", 0.0)   # the rim glow is for characters; on props it reads as plastic edges
	mat.set_shader_parameter(&"albedo_texture", src.albedo_texture if src.albedo_texture else ModelUtil.white_texture())
	mat.set_shader_parameter(&"albedo_color", src.albedo_color)
	mat.set_shader_parameter(&"use_vertex_color", src.vertex_color_use_as_albedo)
	mat.set_shader_parameter(&"uv_scale", Vector2(src.uv1_scale.x, src.uv1_scale.y))
	mat.set_shader_parameter(&"uv_offset", Vector2(src.uv1_offset.x, src.uv1_offset.y))
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		mat.set_shader_parameter(&"alpha_scissor_threshold", src.alpha_scissor_threshold)
	return mat
