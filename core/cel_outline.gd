class_name CelOutline
extends RefCounted
## Adds a black inverted-hull outline behind a MeshInstance3D — the standard
## cel-shading trick, no custom shader needed: a duplicate of the mesh is
## drawn unshaded black, inflated slightly outward along its own normals
## (BaseMaterial3D's built-in `grow`), and culled to its *front* faces so
## only the inflated back faces peek out past the original mesh's silhouette.
##
## Usage: call once per MeshInstance3D after its real material is set up,
## e.g. `CelOutline.apply(mesh_instance, 0.01)`. Works on skinned meshes too
## (duplicate() carries over the skin/skeleton binding, so the outline
## deforms with the animation).

static func apply(mi: MeshInstance3D, thickness: float, color := Color.BLACK) -> MeshInstance3D:
	if mi.mesh == null or thickness <= 0.0:
		return null
	var outline := mi.duplicate() as MeshInstance3D
	outline.name = str(mi.name) + "Outline"
	outline.material_override = _outline_material(thickness, color)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.get_parent().add_child(outline)
	return outline

static func _outline_material(thickness: float, color: Color) -> BaseMaterial3D:
	# BaseMaterial3D is abstract — StandardMaterial3D is the concrete class
	# that actually implements it.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	# NOTE: BaseMaterial3D's actual property names here are `grow` (bool,
	# enables it) and `grow_amount` (float, how far) — not `grow_enabled`/
	# `grow` as the inspector's "Grow > Amount" layout makes it tempting to
	# assume. Getting this wrong doesn't error, it just silently never grows
	# the mesh, so the outline never has anything to show.
	m.grow = true
	m.grow_amount = thickness
	return m
