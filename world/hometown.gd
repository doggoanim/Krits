class_name Hometown
extends Node3D
## The game's first real (if simple) zone — a small plaza built entirely from
## Godot's built-in primitive meshes (boxes, cylinders, prisms). No Blender,
## no terrain plugin: for "basic shapes" set dressing, Godot's own meshes are
## enough, and CSGShape3D/GridMap are the next options if you want to sculpt
## something more organic later (see README's "Building your own map").
##
## Follows the same StaticBody3D / Spawnpoint / WorldEnemy contract as
## TestLevel, just dressed up instead of being a mechanics playground —
## TestLevel is still around for that.

const GRASS := Color(0.36, 0.56, 0.32)
const DIRT_PATH := Color(0.55, 0.42, 0.28)
const STONE := Color(0.62, 0.6, 0.58)
const STONE_LIGHT := Color(0.7, 0.65, 0.55)
const WOOD := Color(0.5, 0.35, 0.22)
const ROOF_RED := Color(0.65, 0.25, 0.2)
const ROOF_BLUE := Color(0.25, 0.35, 0.55)
const FOLIAGE := Color(0.22, 0.45, 0.25)
const HILL_STEP := Color(0.5, 0.42, 0.3)
const HILL_TOP := Color(0.45, 0.55, 0.4)

func _ready() -> void:
	_ground()
	_paths()
	_houses()
	_well()
	_trees()
	_hill()
	_spawns()
	_enemy(&"grove_slime", Vector3(-30, 0.2, 22), EnemyLibrary.green_slime())

## ---------------------------------------------------------------- ground --

func _ground() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 120), GRASS, true)

func _paths() -> void:
	# A cross-shaped dirt path through the plaza, flush with the grass so
	# there's nothing to trip on — just a color change underfoot.
	_box(Vector3(0, 0.01, 0), Vector3(4, 0.05, 44), DIRT_PATH, true)
	_box(Vector3(0, 0.01, 0), Vector3(44, 0.05, 4), DIRT_PATH, true)

## ---------------------------------------------------------------- houses --

func _houses() -> void:
	_house(Vector3(-11, 0, -11), Vector3(6, 4, 6), STONE, ROOF_RED)
	_house(Vector3(11, 0, -13), Vector3(7, 5, 5), STONE_LIGHT, ROOF_BLUE)
	_house(Vector3(-14, 0, 9), Vector3(5, 3.5, 5), STONE, ROOF_RED)
	_house(Vector3(14, 0, 11), Vector3(6, 4.5, 6), STONE_LIGHT, ROOF_BLUE)

## A box building topped with a pitched prism roof. The walls are solid
## (collidable, so you can't walk through them); the roof is visual only —
## it sits above normal jump height, so there's nothing to stand on up there.
func _house(pos: Vector3, size: Vector3, wall_color: Color, roof_color: Color) -> void:
	_box(pos + Vector3(0, size.y * 0.5, 0), size, wall_color)
	var roof := PrismMesh.new()
	roof.size = Vector3(size.x * 1.15, size.y * 0.6, size.z * 1.15)
	_mesh_only(pos + Vector3(0, size.y + roof.size.y * 0.5, 0), roof, roof_color)

## ------------------------------------------------------------------ well --

func _well() -> void:
	var pos := Vector3(0, 0, -6)
	_cylinder(pos + Vector3(0, 0.5, 0), 1.2, 1.0, STONE)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.08
	pole.height = 2.2
	_mesh_only(pos + Vector3(0, 2.1, 0), pole, WOOD)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 1.6
	roof.height = 1.0
	_mesh_only(pos + Vector3(0, 3.5, 0), roof, ROOF_RED)

## ----------------------------------------------------------------- trees --

func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234   # fixed seed — same layout every run, not re-rolled each load
	for i in 16:
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(20.0, 52.0)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_tree(pos, rng.randf_range(0.85, 1.3))

## Thin collidable trunk (so you can't just walk through the tree) topped
## with a cone of foliage, built from a CylinderMesh with top_radius = 0.
func _tree(pos: Vector3, scale_mul := 1.0) -> void:
	var trunk_h := 3.0 * scale_mul
	_cylinder(pos + Vector3(0, trunk_h * 0.5, 0), 0.25 * scale_mul, trunk_h, WOOD)
	var foliage := CylinderMesh.new()
	foliage.top_radius = 0.0
	foliage.bottom_radius = 1.6 * scale_mul
	foliage.height = 3.2 * scale_mul
	_mesh_only(pos + Vector3(0, trunk_h + foliage.height * 0.35, 0), foliage, FOLIAGE)

## ------------------------------------------------------------------ hill --

func _hill() -> void:
	# Same terraced-stairs idea as TestLevel's platform climb, just dressed
	# as a hillside leading up to a lookout over the plaza.
	for i in 3:
		var h := 1.5 * (i + 1)
		_box(Vector3(30 + i * 4, h * 0.5, 0), Vector3(4, h, 10), HILL_STEP, true)
	_box(Vector3(42, 4.5, 0), Vector3(10, 1, 10), HILL_TOP, true)

## --------------------------------------------------------------- spawns --

func _spawns() -> void:
	_spawn(&"start", "Town Square", Vector3(8, 0, 14))
	_spawn(&"overlook", "Hilltop", Vector3(42, 5.0, 0))

## ------------------------------------------------------------ primitives --
## Same shape-builder pattern as TestLevel: a StaticBody3D with a matching
## CollisionShape3D + MeshInstance3D for anything solid, and a bare
## MeshInstance3D for anything decorative. `is_floor` marks a solid shape as
## walkable ground (CameraRig.GROUND_LAYER) on top of the regular "world"
## layer — see TestLevel._box() for why that matters for camera collision.

func _box(pos: Vector3, size: Vector3, col: Color, is_floor := false) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | (CameraRig.GROUND_LAYER if is_floor else 0)
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	body.add_child(mi)
	add_child(body)

func _cylinder(pos: Vector3, radius: float, height: float, col: Color, is_floor := false) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | (CameraRig.GROUND_LAYER if is_floor else 0)
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	body.add_child(mi)
	add_child(body)

## No collision at all — purely visual set dressing (roofs, foliage, the
## well's roof and center pole).
func _mesh_only(pos: Vector3, mesh: Mesh, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	add_child(mi)

func _spawn(id: StringName, nm: String, pos: Vector3) -> void:
	var sp := Spawnpoint.new()
	sp.spawn_id = id
	sp.display_name = nm
	sp.position = pos
	add_child(sp)

func _enemy(id: StringName, pos: Vector3, data: EnemyData) -> void:
	var e := WorldEnemy.new()
	e.enemy_id = id
	e.data = data
	e.position = pos
	add_child(e)
