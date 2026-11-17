@tool
class_name HouseDressing
extends Node
## Gives every house under the parent node (Buildings in chesburg.tscn) a brick chimney
## with a slow wisp of smoke, so the identical houses stop looking copy-pasted. The roof
## height is read from the roof's own triangles, so the chimney stands on the roof
## wherever the house sits. Each house gets a different spot and size.
##
## It also runs in the editor: the chimneys show up in the scene view but are never
## saved into the scene (they have no owner), so chesburg.tscn doesn't change.

## Where a chimney may stand, in a house's own space (x, z). Each house starts at a
## different one (house order) and takes the first that actually has roof under it.
const SPOTS: Array[Vector2] = [
	Vector2(-1.9, -0.9), Vector2(1.8, -0.5), Vector2(0.0, 0.6),
	Vector2(1.6, 0.8), Vector2(-1.2, -0.5), Vector2(-2.0, 0.7),
]
## Chimney size (width = depth, height) per house, in the same order.
const SIZES: Array[Vector2] = [
	Vector2(0.75, 1.7), Vector2(0.9, 1.4), Vector2(0.7, 2.0),
	Vector2(0.8, 1.6), Vector2(0.7, 1.5), Vector2(0.85, 1.9),
]
const CHIMNEY_NAME := "Chimney"
const CHIMNEY_SINK := 0.5           ## how far the chimney's base is buried into the roof
const BRICK := Color(0.62, 0.38, 0.32)
const BRICK_DARK := Color(0.4, 0.26, 0.24)
const TOON: Shader = preload("res://shading/toon.gdshader")
const SMOKE_TEXTURE: Texture2D = preload("res://assets/sprites/smoke_puff.png")

## Houses to dress: nodes in the parent whose name contains one of these.
@export var name_filter: PackedStringArray = ["house_chesburg"]
## Shifts which spot/size each house gets; change it to reshuffle.
@export var seed_offset := 0
## Chimneys puff smoke.
@export var chimney_smoke := true

func _ready() -> void:
	var holder := get_parent()
	if holder == null:
		return
	var index := 0
	for child in holder.get_children():
		if child is Node3D and _matches(child.name):
			_dress(child as Node3D, index + seed_offset)
			index += 1

func _matches(node_name: String) -> bool:
	for f in name_filter:
		if node_name.containsn(f):
			return true
	return false

func _dress(house: Node3D, index: int) -> void:
	var old := house.get_node_or_null(CHIMNEY_NAME)
	if old != null:
		old.queue_free()   # re-running (the editor reloading the script) must not stack chimneys
	var size := SIZES[index % SIZES.size()]
	for k in SPOTS.size():   # first spot with roof under it
		var spot := SPOTS[(index + k) % SPOTS.size()]
		if _add_chimney(house, spot, size):
			return

# ----------------------------------------------------------------- chimney

## A brick chimney standing on the roof (its base sinks into the roof's surface,
## found from the roof's own triangles) with a slow wisp of smoke.
func _add_chimney(house: Node3D, xz: Vector2, size: Vector2) -> bool:
	var roof_y := _roof_height(house, xz)
	if is_nan(roof_y):
		return false
	var dims := Vector3(size.x, size.y, size.x)
	var chimney := Node3D.new()
	chimney.name = CHIMNEY_NAME
	chimney.position = Vector3(xz.x, roof_y - CHIMNEY_SINK, xz.y)
	house.add_child(chimney)   # no owner on purpose: shown in the editor, never saved
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dims
	shaft.mesh = box
	shaft.material_override = _toon(BRICK)
	shaft.position.y = dims.y * 0.5
	chimney.add_child(shaft)
	var cap := MeshInstance3D.new()
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(dims.x + 0.2, 0.18, dims.z + 0.2)
	cap.mesh = cap_box
	cap.material_override = _toon(BRICK_DARK)
	cap.position.y = dims.y + 0.09
	chimney.add_child(cap)
	if chimney_smoke:
		_add_smoke(chimney, Vector3(0.0, dims.y + 0.25, 0.0))
	return true

func _toon(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter(&"albedo_texture", ModelUtil.white_texture())
	m.set_shader_parameter(&"albedo_color", color)
	m.set_shader_parameter(&"rim_strength", 0.0)
	return m

func _add_smoke(chimney: Node3D, at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 8
	p.lifetime = 4.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.25, 0.1, 0.0)   # drifts off with the breeze
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(0.93, 0.93, 0.95, 0.5), Color(0.9, 0.9, 0.95, 0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = SMOKE_TEXTURE
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	chimney.add_child(p)

## Height of the roof's surface at (x, z) in the house's own space: the highest roof
## triangle covering that point. NAN when the roof isn't there.
func _roof_height(house: Node3D, xz: Vector2) -> float:
	var best := NAN
	var inverse := house.global_transform.affine_inverse()
	for m in house.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or String(mi.name).containsn("collision"):
			continue
		var to_house := inverse * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(surface)
			if mat == null or not mat.resource_name.to_lower().contains("roof"):
				continue
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var count: int = (indices.size() if indices != null else verts.size())
			for t in range(0, count - 2, 3):
				var a := to_house * verts[indices[t] if indices != null else t]
				var b := to_house * verts[indices[t + 1] if indices != null else t + 1]
				var c := to_house * verts[indices[t + 2] if indices != null else t + 2]
				var y := _height_in_triangle(xz, a, b, c)
				if not is_nan(y) and (is_nan(best) or y > best):
					best = y
	return best

## The height of triangle (a, b, c)'s plane at xz, or NAN if xz is outside it (seen from above).
static func _height_in_triangle(xz: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(xz.x - a.x, xz.y - a.z)
	var denom := v0.x * v1.y - v1.x * v0.y
	if absf(denom) < 0.00001:
		return NAN
	var u := (v2.x * v1.y - v1.x * v2.y) / denom
	var v := (v0.x * v2.y - v2.x * v0.y) / denom
	if u < 0.0 or v < 0.0 or u + v > 1.0:
		return NAN
	return a.y + u * (b.y - a.y) + v * (c.y - a.y)
