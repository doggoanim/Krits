class_name ModelUtil
extends RefCounted
## Shared helpers for loading a rigged glTF character model consistently
## across the game. PlayerVisual and EnemyVisual both call these, so the
## player and every animated enemy get the same treatment: auto-scaled to a
## target height regardless of export units, cel-shaded (shading/toon.gdshader
## — banded lighting *and* a hard-edged shadow, not just the built-in
## DIFFUSE_TOON render mode, which bands the lighting but leaves the shadow
## itself soft — see that shader's own header comment for why). Outlining
## itself is a separate, optional step (see apply_cel_shading's outline_hook
## param and OutlineSystem) so it can vary independently of shading.

const CEL_SHADER := preload("res://shading/toon.gdshader")

## Some character materials (krits.glb's among them) are authored with
## baseColorFactor deliberately black and the real, often pre-shaded color
## living entirely in emission - meant to be rendered unshaded. _shade_recursive()
## detects `emission_enabled` and sources color/texture from there instead of
## albedo in that case, so the dynamic banded lighting below still has an
## actual color to work with instead of reading the (intentionally black)
## base color.

## A model with no actual albedo texture (flat-colored or vertex-painted)
## has `albedo_texture == null`. Explicitly binding a shader's sampler2D
## parameter to null reads back as solid black rather than falling back to
## white the way an *untouched* parameter would — learned the hard way with
## TrampleMap's grass bending — so untextured materials get this instead of
## null, rather than relying on that fallback behavior at all.
static var _white_texture: Texture2D

static func _get_white_texture() -> Texture2D:
	if _white_texture == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		_white_texture = ImageTexture.create_from_image(img)
	return _white_texture

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
## (shading/toon.gdshader — see CEL_SHADER above). Appends every new
## ShaderMaterial to `out_materials` if given, so a caller (flash-on-hit,
## slime tinting, ...) can modify them later without re-walking the tree —
## use get_tint()/set_tint() below rather than poking the shader parameter
## directly, so callers don't need to know its name.
##
## Any surface whose source material name starts with "Face" (case-insensitive
## — the krits.glb convention is a single flat face material per head mesh,
## "Face_Idle" being the one baked expression that model ships with today) is
## also added to `out_face_materials`, keyed by that original name. A model
## authored with more than one face surface (unlikely, but not assumed away)
## ends up with more than one entry. Callers that want to swap expressions
## (PlayerVisual.set_expression) use this instead of hunting for "the face"
## by node path or surface index — see set_albedo_texture() below for how to
## actually retexture one once found.
##
## Outlining is a separate concern on purpose (see OutlineSystem) — shading
## only decides what a surface looks like, not whether it gets an outline,
## so the two can vary independently (PortraitViewport still wants its own
## isolated per-mesh outline; PlayerVisual/EnemyVisual want the shared
## screen-space one). Pass `outline_hook` to get a callback per
## MeshInstance3D right after its material is set up — typically
## `Callable(OutlineSystem, &"mark")` — or leave it empty for no outline at
## all.
static func apply_cel_shading(model: Node3D, out_materials: Array = [],
		out_face_materials: Dictionary = {}, outline_hook := Callable()) -> void:
	_shade_recursive(model, out_materials, out_face_materials, outline_hook)

static func _shade_recursive(n: Node, out_materials: Array, out_face_materials: Dictionary,
		outline_hook: Callable) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count() if mi.mesh else 0:
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var base := mat as BaseMaterial3D
				var cel := ShaderMaterial.new()
				cel.shader = CEL_SHADER

				var color_tex: Texture2D
				var tint: Color
				var use_vertex_color := base.vertex_color_use_as_albedo
				if base.emission_enabled:
					# Some models (krits.glb among them) are authored with
					# baseColorFactor deliberately black and their actual,
					# often pre-shaded color living entirely in emission —
					# meant to render unshaded. Feeding that into our normal
					# albedo pipeline instead lets the dynamic banded
					# lighting/shadow below apply to it like any other
					# material, rather than reading the (intentionally
					# black) base color and rendering nothing.
					color_tex = base.emission_texture if base.emission_texture else _get_white_texture()
					var mult := base.emission_energy_multiplier
					tint = Color(base.emission.r * mult, base.emission.g * mult, base.emission.b * mult, base.albedo_color.a)
					use_vertex_color = false
				else:
					color_tex = base.albedo_texture if base.albedo_texture else _get_white_texture()
					tint = base.albedo_color
					# A model whose actual color comes from vertex colors
					# (common for simple/stylized exports) often leaves
					# albedo_color at a literal black, since the source
					# material never meant it to be read on its own — it's
					# only a factor multiplied with the vertex color. If
					# nothing else is going to supply color (no texture, no
					# vertex color either) a flat black tint is never
					# actually intentional, so fall back to white.
					if tint.r < 0.001 and tint.g < 0.001 and tint.b < 0.001 \
							and not use_vertex_color and base.albedo_texture == null:
						tint = Color.WHITE

				cel.set_shader_parameter(&"albedo_texture", color_tex)
				cel.set_shader_parameter(&"albedo_color", tint)
				cel.set_shader_parameter(&"use_vertex_color", use_vertex_color)
				mi.set_surface_override_material(i, cel)
				out_materials.append(cel)
				if base.resource_name.to_lower().begins_with("face"):
					out_face_materials[base.resource_name] = cel
		if outline_hook.is_valid():
			outline_hook.call(mi)
	for c in n.get_children():
		_shade_recursive(c, out_materials, out_face_materials, outline_hook)

## Thin wrappers around the cel material's tint parameter, so flash-on-hit,
## slime tinting etc. don't need to know shading/toon.gdshader's parameter
## name or that it's a shader at all.
static func get_tint(material: ShaderMaterial) -> Color:
	return material.get_shader_parameter(&"albedo_color")

static func set_tint(material: ShaderMaterial, color: Color) -> void:
	material.set_shader_parameter(&"albedo_color", color)

## Swaps a cel-shaded surface's texture entirely — what a face-expression
## change actually is (see PlayerVisual.set_expression): a different baked
## texture on the same flat face mesh, not a different mesh or a blend shape
## (krits.glb has no morph targets). `tex` is used as-is, so callers must
## supply something non-null themselves — unlike _shade_recursive()'s own
## initial setup, there's no sensible "untextured" fallback for an explicit
## expression swap.
static func set_albedo_texture(material: ShaderMaterial, tex: Texture2D) -> void:
	material.set_shader_parameter(&"albedo_texture", tex)
