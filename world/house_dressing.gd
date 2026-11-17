class_name HouseDressing
extends Node
## Stops a town of identical houses reading as copy-paste: each house under the parent
## node (Buildings in chesburg.tscn) is "dressed" with its own set of props from RECIPES
## (a flower bed, a woodpile, a garden, a signpost, a fence, a smoking chimney...).
## The models themselves aren't touched; everything is added as children of the house,
## so props follow it if it moves.
##
## A prop is placed relative to the house's own footprint, so the same recipe fits a small
## house and a long one: a `side` of the house (its front is its +Z, where the door is),
## a position `along` that side, and how far `out` from the wall.
##
## Recipes are handed out in house order and repeat only after every one has been used,
## and ground props are snapped down to the terrain once physics is ready.

const NATURE := "res://assets/world/nature/"
const WORLD := "res://assets/world/"

## One recipe per look. A prop is {scene, side, along, out, yaw (extra degrees), scale, wind}.
## `wind` adds the sway (and step-through reaction) that grass, flowers and bushes get.
## A "chimney" entry is {chimney = true, x, z} in the house's own space.
const RECIPES: Array = [
	{   # flower beds at the door
		"name": "flower beds",
		"props": [
			{"scene": NATURE + "red_flower.glb", "side": "front", "along": -2.6, "out": 0.8, "wind": true},
			{"scene": NATURE + "red_flower.glb", "side": "front", "along": -2.0, "out": 1.1, "wind": true},
			{"scene": NATURE + "red_flower.glb", "side": "front", "along": -3.0, "out": 1.2, "wind": true},
			{"scene": NATURE + "blue_flower.glb", "side": "front", "along": 2.4, "out": 0.8, "wind": true},
			{"scene": NATURE + "blue_flower.glb", "side": "front", "along": 2.9, "out": 1.1, "wind": true},
			{"chimney": true, "x": -1.9, "z": -0.9},
		],
	},
	{   # a woodcutter's side yard
		"name": "woodpile",
		"props": [
			{"scene": NATURE + "log.glb", "side": "right", "along": 0.6, "out": 1.0, "yaw": 90.0},
			{"scene": NATURE + "log.glb", "side": "right", "along": -0.6, "out": 1.1, "yaw": 84.0, "scale": 0.85},
			{"scene": NATURE + "tree_stump_1.glb", "side": "right", "along": -2.2, "out": 1.0},
			{"scene": NATURE + "yellow_flower.glb", "side": "front", "along": -2.5, "out": 0.9, "wind": true},
			{"scene": NATURE + "yellow_flower.glb", "side": "front", "along": -2.0, "out": 1.2, "wind": true},
			{"chimney": true, "x": 1.8, "z": -0.5},
		],
	},
	{   # a gardener's bushes and a signpost
		"name": "garden",
		"props": [
			{"scene": NATURE + "bush.glb", "side": "left", "along": 1.8, "out": 1.0, "wind": true},
			{"scene": NATURE + "berry_bush.glb", "side": "right", "along": -1.2, "out": 1.0, "wind": true},
			{"scene": NATURE + "green_flower.glb", "side": "front", "along": -1.9, "out": 0.9, "wind": true},
			{"scene": NATURE + "green_flower.glb", "side": "front", "along": -2.5, "out": 1.2, "wind": true},
			{"scene": NATURE + "green_flower.glb", "side": "front", "along": -3.0, "out": 0.9, "wind": true},
			{"scene": WORLD + "sign.glb", "side": "front", "along": 2.9, "out": 2.0, "yaw": 20.0},
		],
	},
	{   # rocks, a signpost and a chimney
		"name": "signpost",
		"props": [
			{"scene": WORLD + "sign.glb", "side": "front", "along": 2.6, "out": 2.2, "yaw": -15.0},
			{"scene": NATURE + "rock_3.glb", "side": "left", "along": 2.4, "out": 1.0, "scale": 0.6},
			{"scene": NATURE + "rock_4.glb", "side": "left", "along": 1.2, "out": 1.4, "scale": 0.45},
			{"scene": NATURE + "blue_flower.glb", "side": "front", "along": -2.5, "out": 0.9, "wind": true},
			{"scene": NATURE + "blue_flower.glb", "side": "front", "along": -3.0, "out": 1.2, "wind": true},
			{"chimney": true, "x": 0.0, "z": 0.6},
		],
	},
	{   # a little fenced front yard
		"name": "fenced yard",
		"props": [
			{"scene": WORLD + "fence.glb", "side": "front", "along": -3.4, "out": 2.4},
			{"scene": WORLD + "fence.glb", "side": "front", "along": 3.4, "out": 2.4},
			{"scene": WORLD + "fence.glb", "side": "front", "along": -4.7, "out": 1.1, "yaw": 90.0},
			{"scene": WORLD + "fence.glb", "side": "front", "along": 4.7, "out": 1.1, "yaw": 90.0},
			{"scene": NATURE + "red_flower.glb", "side": "front", "along": -2.5, "out": 1.0, "wind": true},
			{"scene": NATURE + "red_flower.glb", "side": "front", "along": 2.5, "out": 1.0, "wind": true},
			{"chimney": true, "x": 1.6, "z": 0.8},
		],
	},
	{   # mossy and overgrown
		"name": "overgrown",
		"props": [
			{"scene": NATURE + "tree_stump_2.glb", "side": "left", "along": -1.5, "out": 1.2},
			{"scene": NATURE + "rock_1.glb", "side": "right", "along": 1.0, "out": 1.2, "scale": 0.7},
			{"scene": NATURE + "berry_bush.glb", "side": "left", "along": 1.8, "out": 1.0, "wind": true},
			{"scene": NATURE + "bush.glb", "side": "right", "along": -2.5, "out": 1.0, "wind": true},
			{"scene": NATURE + "yellow_flower.glb", "side": "front", "along": 2.4, "out": 1.0, "wind": true},
			{"scene": NATURE + "yellow_flower.glb", "side": "front", "along": 3.0, "out": 1.3, "wind": true},
			{"chimney": true, "x": -1.2, "z": -0.5},
		],
	},
]

const FIND_GROUND_UP := 2.0         ## a prop's ground ray starts this far above the house's base...
const FIND_GROUND_DOWN := 6.0       ## ...and reaches this far down
const WORLD_LAYER := 1
const CHIMNEY_SIZE := Vector3(0.75, 1.7, 0.75)
const CHIMNEY_SINK := 0.5           ## how far the chimney's base is buried into the roof
const BRICK := Color(0.62, 0.38, 0.32)
const BRICK_DARK := Color(0.4, 0.26, 0.24)
const TOON: Shader = preload("res://shading/toon.gdshader")
const SMOKE_TEXTURE: Texture2D = preload("res://assets/sprites/smoke_puff.png")

## Houses to dress: nodes in the parent whose name contains one of these.
@export var name_filter: PackedStringArray = ["house_chesburg"]
## Shifts which recipe each house gets; change it to reshuffle.
@export var seed_offset := 0
## Chimneys puff smoke.
@export var chimney_smoke := true

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var holder := get_parent()
	if holder == null:
		return
	var index := 0
	for child in holder.get_children():
		if child is Node3D and _matches(child.name):
			_dress(child as Node3D, (index + seed_offset) % RECIPES.size())
			index += 1

func _matches(node_name: String) -> bool:
	for f in name_filter:
		if node_name.containsn(f):
			return true
	return false

# ---------------------------------------------------------------- dressing

func _dress(house: Node3D, recipe_index: int) -> void:
	var box := _footprint(house)
	var snaps: Array[Node3D] = []
	for entry in RECIPES[recipe_index]["props"]:
		if entry.get("chimney", false):
			_add_chimney(house, Vector2(entry["x"], entry["z"]))
			continue
		var scene := load(entry["scene"]) as PackedScene
		if scene == null:
			continue
		var prop := scene.instantiate() as Node3D
		var side: String = entry["side"]
		prop.position = _spot(box, side, entry["along"], entry["out"])
		prop.rotation_degrees.y = _side_yaw(side) + float(entry.get("yaw", 0.0))
		var s := float(entry.get("scale", 1.0))
		prop.scale = Vector3.ONE * s
		house.add_child(prop)
		if entry.get("wind", false):
			var wind := FoliageWind.new()
			wind.name = "Wind"
			prop.add_child(wind)
		snaps.append(prop)
	_snap_to_ground.call_deferred(house, snaps)

## The house's footprint in its own space (its visible meshes, not its collision helpers).
func _footprint(house: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inverse := house.global_transform.affine_inverse()
	for m in house.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or String(mi.name).containsn("collision"):
			continue
		var b := (inverse * mi.global_transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(Vector3(-3.0, 0.0, -3.0), Vector3(6.0, 6.0, 6.0))
	return box

## A spot beside the house in its own space: on `side`, `along` it, `out` from the wall.
func _spot(box: AABB, side: String, along: float, out: float) -> Vector3:
	match side:
		"right":
			return Vector3(box.end.x + out, 0.0, along)
		"left":
			return Vector3(box.position.x - out, 0.0, along)
		"back":
			return Vector3(along, 0.0, box.position.z - out)
	return Vector3(along, 0.0, box.end.z + out)   # front

## The yaw that makes a prop face away from `side`'s wall (a signpost's face points outward).
func _side_yaw(side: String) -> float:
	match side:
		"right":
			return 90.0
		"left":
			return -90.0
		"back":
			return 180.0
	return 0.0

## Drops each prop onto the terrain below it. Waits a physics frame so colliders exist.
func _snap_to_ground(house: Node3D, props: Array[Node3D]) -> void:
	await get_tree().physics_frame
	var space := house.get_world_3d().direct_space_state
	for prop in props:
		if not is_instance_valid(prop):
			continue
		var top := prop.global_position
		top.y = house.global_position.y + FIND_GROUND_UP
		var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (FIND_GROUND_UP + FIND_GROUND_DOWN), WORLD_LAYER)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			prop.global_position.y = (hit["position"] as Vector3).y

# ----------------------------------------------------------------- chimney

## A brick chimney standing on the roof (its base sinks into the roof's surface,
## found from the roof's own triangles) with a slow wisp of smoke.
func _add_chimney(house: Node3D, xz: Vector2) -> void:
	var roof_y := _roof_height(house, xz)
	if is_nan(roof_y):
		return
	var chimney := Node3D.new()
	chimney.name = "Chimney"
	chimney.position = Vector3(xz.x, roof_y - CHIMNEY_SINK, xz.y)
	house.add_child(chimney)
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = CHIMNEY_SIZE
	shaft.mesh = box
	shaft.material_override = _toon(BRICK)
	shaft.position.y = CHIMNEY_SIZE.y * 0.5
	chimney.add_child(shaft)
	var cap := MeshInstance3D.new()
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(CHIMNEY_SIZE.x + 0.2, 0.18, CHIMNEY_SIZE.z + 0.2)
	cap.mesh = cap_box
	cap.material_override = _toon(BRICK_DARK)
	cap.position.y = CHIMNEY_SIZE.y + 0.09
	chimney.add_child(cap)
	if chimney_smoke:
		_add_smoke(chimney, Vector3(0.0, CHIMNEY_SIZE.y + 0.25, 0.0))

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
