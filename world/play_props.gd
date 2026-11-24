@tool
class_name PlayProps
extends RefCounted
## Looks for the props you can DO things to: pots, crates and barrels that smash, a bouncy
## mushroom, a ball and a bucket to kick, a bench and a log to sit on, the town bell, and
## things to gather. Every builder returns a Node3D standing on y = 0; the behaviour lives in
## PlayProp / KickableProp / Seat / TownBell / Gatherable, which call these.
## Same conventions as HouseProps (HouseParts.toon materials, one function per prop).

const CLAY := Color(0.78, 0.45, 0.3)
const CLAY_DARK := Color(0.6, 0.33, 0.24)
const GOLD := Color(0.9, 0.72, 0.25)
const CAP_RED := Color(0.78, 0.22, 0.24)
const CREAM := Color(0.95, 0.9, 0.78)

static func pot() -> Node3D:
	var root := Node3D.new()
	_ball(root, 0.3, CLAY, Vector3(0, 0.3, 0), Vector3(1.0, 0.95, 1.0))
	HouseParts.cylinder(root, 0.17, 0.12, CLAY_DARK, Vector3(0, 0.62, 0))
	HouseParts.cylinder(root, 0.2, 0.05, CLAY, Vector3(0, 0.7, 0))
	HouseParts.box(root, Vector3(0.5, 0.04, 0.04), CLAY_DARK, Vector3(0, 0.34, 0.0))   # decorative band
	return root

static func crate() -> Node3D:
	var root := Node3D.new()
	var wood := HouseParts.WOOD_LIGHT
	HouseParts.box(root, Vector3(0.7, 0.7, 0.7), wood, Vector3(0, 0.35, 0))
	for x in [-0.33, 0.33]:
		for z in [-0.33, 0.33]:
			HouseParts.box(root, Vector3(0.08, 0.72, 0.08), HouseParts.WOOD_DARK, Vector3(x, 0.36, z))
	HouseParts.box(root, Vector3(0.72, 0.08, 0.72), HouseParts.WOOD_DARK, Vector3(0, 0.7, 0))
	HouseParts.box(root, Vector3(0.72, 0.08, 0.72), HouseParts.WOOD_DARK, Vector3(0, 0.04, 0))
	HouseParts.box(root, Vector3(0.7, 0.06, 0.04), HouseParts.WOOD_DARK, Vector3(0, 0.36, 0.36), Vector3(0, 0, 38))
	return root

static func barrel() -> Node3D:
	var root := Node3D.new()
	HouseParts.cylinder(root, 0.34, 0.8, HouseParts.WOOD_LIGHT.darkened(0.08), Vector3(0, 0.4, 0))
	HouseParts.cylinder(root, 0.37, 0.14, HouseParts.WOOD_LIGHT.darkened(0.08), Vector3(0, 0.4, 0))   # belly
	for y in [0.14, 0.66]:
		HouseParts.cylinder(root, 0.385, 0.06, HouseParts.IRON, Vector3(0, y, 0))
	HouseParts.cylinder(root, 0.3, 0.02, HouseParts.WOOD_DARK, Vector3(0, 0.8, 0))
	return root

## Big spongy cap you can bounce on.
static func mushroom() -> Node3D:
	var root := Node3D.new()
	HouseParts.cylinder(root, 0.2, 0.45, CREAM, Vector3(0, 0.22, 0))
	_ball(root, 0.78, CAP_RED, Vector3(0, 0.45, 0), Vector3(1.0, 0.5, 1.0))
	for spot in [Vector3(0.3, 0.8, 0.1), Vector3(-0.28, 0.78, 0.22), Vector3(0.05, 0.84, -0.32), Vector3(-0.1, 0.86, 0.02)]:
		_ball(root, 0.11, CREAM, spot, Vector3(1.0, 0.45, 1.0))
	return root

static func ball() -> Node3D:
	var root := Node3D.new()
	_ball(root, 0.28, Color(0.88, 0.3, 0.3), Vector3(0, 0.28, 0))
	HouseParts.box(root, Vector3(0.58, 0.08, 0.08), CREAM, Vector3(0, 0.28, 0))   # stripe
	return root

static func bucket() -> Node3D:
	var root := Node3D.new()
	HouseParts.cylinder(root, 0.22, 0.34, HouseParts.WOOD_LIGHT, Vector3(0, 0.17, 0))
	for y in [0.07, 0.27]:
		HouseParts.cylinder(root, 0.235, 0.04, HouseParts.IRON, Vector3(0, y, 0))
	HouseParts.box(root, Vector3(0.46, 0.03, 0.03), HouseParts.IRON, Vector3(0, 0.42, 0), Vector3(0, 0, 0))
	return root

## A bench seat 1.6 m wide, facing local +Z (sit with your back to -Z).
static func bench() -> Node3D:
	var root := Node3D.new()
	HouseParts.box(root, Vector3(1.6, 0.08, 0.5), HouseParts.WOOD_LIGHT, Vector3(0, 0.46, 0))
	HouseParts.box(root, Vector3(1.6, 0.34, 0.06), HouseParts.WOOD_LIGHT.darkened(0.06), Vector3(0, 0.78, -0.22), Vector3(-8, 0, 0))
	for x in [-0.68, 0.68]:
		HouseParts.box(root, Vector3(0.1, 0.46, 0.46), HouseParts.WOOD_DARK, Vector3(x, 0.23, 0))
	return root

## A fallen log to perch on; faces local +Z.
static func log_seat() -> Node3D:
	var root := Node3D.new()
	var logm := HouseParts.cylinder(root, 0.26, 1.5, HouseParts.WOOD_DARK, Vector3(0, 0.26, 0))
	logm.rotation_degrees = Vector3(0, 0, 90)
	for x in [-0.75, 0.75]:
		var cap := HouseParts.cylinder(root, 0.22, 0.03, HouseParts.WOOD_LIGHT, Vector3(x, 0.26, 0))
		cap.rotation_degrees = Vector3(0, 0, 90)
	return root

## The town bell on its frame. The returned node has a "Bell" child pivot (swings about its X axis).
static func bell_post() -> Node3D:
	var root := Node3D.new()
	for x in [-0.55, 0.55]:
		HouseParts.box(root, Vector3(0.14, 2.6, 0.14), HouseParts.WOOD_DARK, Vector3(x, 1.3, 0))
	HouseParts.box(root, Vector3(1.4, 0.14, 0.16), HouseParts.WOOD_DARK, Vector3(0, 2.55, 0))
	HouseParts.box(root, Vector3(1.4, 0.1, 0.12), HouseParts.WOOD_DARK, Vector3(0, 0.1, 0))
	var pivot := Node3D.new()
	pivot.name = "Bell"
	pivot.position = Vector3(0, 2.45, 0)
	root.add_child(pivot)
	_mesh(pivot, _cone(0.34, 0.16, 0.55), GOLD, Vector3(0, -0.42, 0))
	_ball(pivot, 0.07, HouseParts.IRON, Vector3(0, -0.74, 0))   # clapper
	HouseParts.cylinder(pivot, 0.03, 0.2, HouseParts.IRON, Vector3(0, -0.1, 0))
	return root

# ------------------------------------------------------------ gatherables

static func moss_clump() -> Node3D:
	var root := Node3D.new()
	for i in 5:
		var a := TAU * float(i) / 5.0
		_ball(root, 0.16, Color(0.25, 0.55, 0.3).lightened(0.05 * i), Vector3(cos(a) * 0.17, 0.1, sin(a) * 0.17), Vector3(1, 0.6, 1))
	_ball(root, 0.2, Color(0.3, 0.65, 0.35), Vector3(0, 0.14, 0), Vector3(1, 0.7, 1))
	return root

static func crystal_shard() -> Node3D:
	var root := Node3D.new()
	var glow := Color(0.5, 0.9, 1.0)
	for spec in [[Vector3(0, 0, 0), 0.5, 0.0], [Vector3(0.14, 0, 0.06), 0.32, 18.0], [Vector3(-0.12, 0, -0.04), 0.26, -22.0]]:
		var shard := _mesh(root, _cone(0.0, 0.09, spec[1]), glow, spec[0] + Vector3(0, spec[1] * 0.5, 0))
		shard.rotation_degrees = Vector3(0, 0, spec[2])
	var light := OmniLight3D.new()
	light.light_color = glow
	light.light_energy = 0.7
	light.omni_range = 3.0
	light.position = Vector3(0, 0.4, 0)
	root.add_child(light)
	return root

static func coin_pile() -> Node3D:
	var root := Node3D.new()
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.4
		var r := 0.1 + 0.05 * float(i % 3)
		var coin := HouseParts.cylinder(root, 0.07, 0.015, GOLD.darkened(0.12 * (i % 2)), Vector3(cos(a) * r, 0.02 + 0.016 * (i % 3), sin(a) * r))
		coin.rotation_degrees = Vector3(randf_range(-12, 12), a * 57.3, randf_range(-12, 12))
	return root

static func web_clump() -> Node3D:
	var root := Node3D.new()
	var silk := Color(0.92, 0.94, 0.98)
	for i in 4:
		var strand := HouseParts.box(root, Vector3(0.5, 0.012, 0.012), silk, Vector3(0, 0.25, 0), Vector3(0, i * 45.0, 25.0 if i % 2 == 0 else -25.0))
		strand.position.y = 0.22 + 0.04 * i
	_ball(root, 0.14, silk, Vector3(0, 0.25, 0), Vector3(1.2, 0.8, 1.2))
	return root

# ------------------------------------------------------------------ helpers

static func _mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	return HouseParts._part(parent, mesh, color, pos)

static func _ball(parent: Node3D, radius: float, color: Color, pos: Vector3, stretch := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var mi := _mesh(parent, mesh, color, pos)
	mi.scale = stretch
	return mi

static func _cone(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	return mesh
