class_name InteriorParts
extends RefCounted
## Fantasy furniture and magic bits for rooms, built from simple shapes with the toon
## shader (see HouseParts for the shared helpers). Every builder returns a Node3D whose
## origin is on the floor (or the ceiling for hanging things) and whose front is +Z, so
## the caller only has to position and turn it. Big pieces carry a box collision.

const STONE := Color(0.55, 0.54, 0.58)
const STONE_DARK := Color(0.32, 0.31, 0.36)
const WOOD := Color(0.5, 0.33, 0.2)
const WOOD_DARK := Color(0.33, 0.21, 0.14)
const GOLD := Color(0.9, 0.72, 0.3)
const VELVET := Color(0.36, 0.2, 0.52)
const VELVET_DARK := Color(0.24, 0.13, 0.36)
const PARCHMENT := Color(0.94, 0.88, 0.7)
const IRON := Color(0.17, 0.17, 0.2)
const CRYSTAL := Color(0.55, 0.82, 1.0)
const FLAME := Color(1.0, 0.62, 0.2)
const BOOK_COLORS: Array[Color] = [
	Color(0.55, 0.18, 0.2), Color(0.2, 0.32, 0.55), Color(0.2, 0.45, 0.3), Color(0.5, 0.35, 0.15),
	Color(0.4, 0.2, 0.5), Color(0.75, 0.65, 0.4),
]
const JAR_COLORS: Array[Color] = [
	Color(0.75, 0.3, 0.25), Color(0.85, 0.62, 0.25), Color(0.5, 0.65, 0.3), Color(0.6, 0.35, 0.45), Color(0.9, 0.8, 0.5),
]
const ROOF_RED := Color(0.745, 0.2, 0.12)   ## the red of the Chesburg roofs (sampled from the house texture)
const LEAF := Color(0.3, 0.6, 0.28)
enum Fill { BOOKS, JARS }

# ----------------------------------------------------------------- helpers

## A bright, flat, light-ignoring material: flames, crystals, liquids.
static func glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

static func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func _glow_box(parent: Node3D, size: Vector3, color: Color, pos: Vector3) -> void:
	var b := BoxMesh.new()
	b.size = size
	_mesh(parent, b, glow(color), pos)

static func _sphere(parent: Node3D, radius: float, material: Material, pos: Vector3, squash := 1.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 * squash
	s.radial_segments = 16
	s.rings = 8
	return _mesh(parent, s, material, pos)

static func _cone(parent: Node3D, radius: float, height: float, material: Material, pos: Vector3, rot_deg := Vector3.ZERO) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 6
	_mesh(parent, c, material, pos, rot_deg)

## Adds a box collision to `root` so the player can't walk through the piece.
static func solid(root: Node3D, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	root.add_child(body)

static func _light(parent: Node3D, color: Color, energy: float, range_m: float, pos: Vector3, flicker := 0.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.position = pos
	parent.add_child(l)
	if flicker > 0.0:
		HouseParts.when_in_tree(l, func() -> void:
			var t := l.create_tween().set_loops()
			for i in 6:
				t.tween_property(l, "light_energy", energy + randf_range(-flicker, flicker), randf_range(0.06, 0.2)))
	return l

## Soft glowing quads rising from a point: fire sparks, cauldron bubbles, drifting motes.
static func _sparkles(color: Color, amount: int, lifetime: float, size: float, rise: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = rise * 0.6
	p.initial_velocity_max = rise
	p.gravity = Vector3.ZERO
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.9), Color(color, 0.0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

# ------------------------------------------------------------------ floor

## A round rug: trim, field, and a gold medallion in the middle.
static func rug(radius: float, field: Color, trim: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Rug"
	HouseParts.cylinder(root, radius, 0.04, trim, Vector3(0, 0.02, 0))
	HouseParts.cylinder(root, radius * 0.86, 0.05, field, Vector3(0, 0.025, 0))
	HouseParts.cylinder(root, radius * 0.5, 0.06, trim, Vector3(0, 0.03, 0))
	HouseParts.cylinder(root, radius * 0.42, 0.07, GOLD, Vector3(0, 0.035, 0))
	HouseParts.cylinder(root, radius * 0.34, 0.08, field, Vector3(0, 0.04, 0))
	return root

# ------------------------------------------------------------- wall pieces

## A big stone hearth with logs and a flickering fire that lights the room.
static func fireplace() -> Node3D:
	var root := Node3D.new()
	root.name = "Fireplace"
	HouseParts.box(root, Vector3(3.5, 0.25, 1.6), STONE_DARK, Vector3(0, 0.125, 0.3))       # hearth slab
	HouseParts.box(root, Vector3(0.8, 3.2, 1.0), STONE, Vector3(-1.3, 1.6, 0.0))            # left pillar
	HouseParts.box(root, Vector3(0.8, 3.2, 1.0), STONE, Vector3(1.3, 1.6, 0.0))             # right pillar
	HouseParts.box(root, Vector3(3.3, 0.66, 1.1), STONE, Vector3(0, 2.85, 0.0))              # lintel
	HouseParts.box(root, Vector3(3.8, 0.2, 1.4), WOOD_DARK, Vector3(0, 3.3, 0.1))           # mantle
	HouseParts.box(root, Vector3(1.8, 2.5, 0.3), Color(0.08, 0.06, 0.06), Vector3(0, 1.4, -0.4))   # sooty back
	HouseParts.cylinder(root, 0.16, 1.3, WOOD_DARK, Vector3(0, 0.45, 0.0)).rotation_degrees = Vector3(0, 0, 90)
	HouseParts.cylinder(root, 0.14, 1.1, WOOD, Vector3(0.0, 0.62, 0.0)).rotation_degrees = Vector3(90, 0, 25)
	HouseParts.cylinder(root, 0.04, 2.1, IRON, Vector3(0, 1.45, -0.35))    # crane post
	HouseParts.box(root, Vector3(0.9, 0.05, 0.05), IRON, Vector3(0.4, 2.45, -0.1))   # arm
	_sphere(root, 0.34, toon_mat(IRON), Vector3(0.7, 1.55, -0.1), 0.85)               # cooking pot
	var stew := HouseParts.cylinder(root, 0.25, 0.03, Color(0.5, 0.3, 0.15), Vector3(0.7, 1.75, -0.1))
	stew.material_override = toon_mat(Color(0.55, 0.32, 0.18))
	var flames := Node3D.new()
	flames.position = Vector3(0, 0.55, 0)
	root.add_child(flames)
	_cone(flames, 0.38, 1.1, glow(Color(1.0, 0.45, 0.12)), Vector3(0, 0.55, 0))
	_cone(flames, 0.24, 0.8, glow(FLAME), Vector3(0.1, 0.4, 0.05))
	_cone(flames, 0.14, 0.55, glow(Color(1.0, 0.9, 0.5)), Vector3(-0.08, 0.3, 0.08))
	var sparks := _sparkles(FLAME, 10, 1.6, 0.1, 1.6)
	sparks.position = Vector3(0, 1.1, 0)
	root.add_child(sparks)
	_light(root, Color(1.0, 0.58, 0.25), 2.4, 9.0, Vector3(0, 1.4, 1.2), 0.6)
	solid(root, Vector3(3.6, 3.4, 1.2), Vector3(0, 1.7, 0.1))
	return root

## A tall shelf (back panel, uprights, boards) full of books or jars of preserves.
static func shelf(width: float, height: float, fill: int, seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Shelf"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var depth := 0.6
	HouseParts.box(root, Vector3(width - 0.1, height - 0.1, 0.1), WOOD_DARK, Vector3(0, height * 0.5, -depth * 0.5 + 0.08))
	for sx in [-1.0, 1.0]:
		HouseParts.box(root, Vector3(0.12, height, depth), WOOD, Vector3(sx * (width * 0.5 - 0.06), height * 0.5, 0))
	HouseParts.box(root, Vector3(width + 0.1, 0.12, depth + 0.1), WOOD, Vector3(0, height + 0.06, 0))   # crown
	var rows := 4 if fill == Fill.BOOKS else 3
	var gap := (height - 0.15) / rows
	for r in rows:
		var y := 0.1 + r * gap
		HouseParts.box(root, Vector3(width - 0.2, 0.1, depth - 0.04), WOOD, Vector3(0, y, 0.0))
		if fill == Fill.BOOKS:
			_books(root, rng, width - 0.3, y + 0.05, gap - 0.2)
		else:
			_jars(root, rng, width - 0.3, y + 0.05)
	solid(root, Vector3(width, height, depth), Vector3(0, height * 0.5, 0))
	return root

static func _books(root: Node3D, rng: RandomNumberGenerator, span: float, y: float, max_h: float) -> void:
	var x := -span * 0.5
	while x < span * 0.5 - 0.1:
		var w := rng.randf_range(0.08, 0.18)
		var h := rng.randf_range(max_h * 0.6, max_h)
		if rng.randf() < 0.12:
			x += rng.randf_range(0.15, 0.3)   # an empty gap now and then
			continue
		HouseParts.box(root, Vector3(w, h, 0.34), BOOK_COLORS[rng.randi() % BOOK_COLORS.size()], Vector3(x + w * 0.5, y + h * 0.5, 0.02))
		x += w + 0.01

static func _jars(root: Node3D, rng: RandomNumberGenerator, span: float, y: float) -> void:
	var x := -span * 0.5 + 0.2
	while x < span * 0.5 - 0.15:
		var color := JAR_COLORS[rng.randi() % JAR_COLORS.size()]
		var r := rng.randf_range(0.1, 0.15)
		var h := rng.randf_range(0.2, 0.34)
		HouseParts.cylinder(root, r, h, color, Vector3(x, y + h * 0.5, 0.05))
		HouseParts.cylinder(root, r * 1.05, 0.05, PARCHMENT, Vector3(x, y + h + 0.025, 0.05))   # cloth lid
		x += r * 2.0 + rng.randf_range(0.1, 0.28)

## A hanging cloth banner with a gold diamond (origin at its centre-bottom on the wall).
static func banner(cloth: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Banner"
	HouseParts.box(root, Vector3(1.3, 0.12, 0.12), GOLD, Vector3(0, 3.0, 0.08))
	HouseParts.box(root, Vector3(1.1, 2.6, 0.05), cloth, Vector3(0, 1.7, 0.05))
	_cone(root, 0.3, 0.4, toon_mat(cloth), Vector3(0, 0.2, 0.05), Vector3(180, 0, 0))   # pointed end
	HouseParts.box(root, Vector3(0.36, 0.36, 0.04), GOLD, Vector3(0, 2.0, 0.1), Vector3(0, 0, 45))
	HouseParts.box(root, Vector3(0.2, 0.2, 0.05), cloth.darkened(0.3), Vector3(0, 2.0, 0.12), Vector3(0, 0, 45))
	return root

## A heraldic shield with crossed swords, for a hall wall (origin at its centre, front +Z).
static func shield() -> Node3D:
	var root := Node3D.new()
	root.name = "Shield"
	for side in [-1.0, 1.0]:
		HouseParts.box(root, Vector3(0.1, 2.2, 0.06), Color(0.75, 0.78, 0.85), Vector3(0, 0, 0.015 * side), Vector3(0, 0, 38.0 * side))
		HouseParts.box(root, Vector3(0.5, 0.08, 0.08), GOLD, Vector3(-side * 0.62, 0.5, 0.02), Vector3(0, 0, 38.0 * side))
	HouseParts.box(root, Vector3(1.0, 1.2, 0.1), GOLD.darkened(0.2), Vector3(0, 0, 0.06))
	_cone(root, 0.5, 0.5, toon_mat(GOLD.darkened(0.2)), Vector3(0, -0.85, 0.06), Vector3(180, 0, 0))
	HouseParts.box(root, Vector3(0.84, 1.04, 0.1), VELVET, Vector3(0, 0, 0.08))
	_cone(root, 0.42, 0.42, toon_mat(VELVET), Vector3(0, -0.72, 0.08), Vector3(180, 0, 0))
	HouseParts.box(root, Vector3(0.32, 0.32, 0.1), GOLD, Vector3(0, 0.1, 0.12), Vector3(0, 0, 45))
	return root

## A tall standing candelabra.
static func candelabra() -> Node3D:
	var root := Node3D.new()
	root.name = "Candelabra"
	HouseParts.cylinder(root, 0.22, 0.1, GOLD.darkened(0.2), Vector3(0, 0.05, 0))
	HouseParts.cylinder(root, 0.05, 1.6, GOLD, Vector3(0, 0.9, 0))
	HouseParts.box(root, Vector3(0.7, 0.06, 0.06), GOLD, Vector3(0, 1.7, 0))
	for sx in [-0.35, 0.0, 0.35]:
		root.add_child(candle(Vector3(sx, 1.73, 0), sx == 0.0))
	solid(root, Vector3(0.5, 2.2, 0.5), Vector3(0, 1.1, 0))
	return root

## A long carpet runner lying on the floor (length along Z).
static func runner(width: float, length: float, field: Color, trim: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Runner"
	HouseParts.box(root, Vector3(width, 0.04, length), trim, Vector3(0, 0.02, 0))
	HouseParts.box(root, Vector3(width - 0.3, 0.05, length - 0.3), field, Vector3(0, 0.025, 0))
	HouseParts.box(root, Vector3(width - 0.6, 0.06, length - 0.6), trim.darkened(0.15), Vector3(0, 0.03, 0))
	HouseParts.box(root, Vector3(width - 0.75, 0.07, length - 0.75), field, Vector3(0, 0.035, 0))
	return root

## A framed picture hanging on a wall (origin at its centre, front +Z).
static func picture(width: float, height: float, art: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Picture"
	HouseParts.box(root, Vector3(width + 0.16, height + 0.16, 0.06), GOLD.darkened(0.3), Vector3.ZERO)
	HouseParts.box(root, Vector3(width, height, 0.07), PARCHMENT, Vector3.ZERO)
	HouseParts.box(root, Vector3(width * 0.8, height * 0.45, 0.08), art, Vector3(0, -height * 0.15, 0))
	HouseParts.box(root, Vector3(width * 0.8, height * 0.28, 0.08), art.lerp(Color(0.6, 0.8, 1.0), 0.7), Vector3(0, height * 0.22, 0))
	return root

## A window letting in warm daylight (origin at its centre, front +Z).
static func window(width: float, height: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Window"
	HouseParts.box(root, Vector3(width + 0.3, height + 0.3, 0.1), WOOD_DARK, Vector3.ZERO)
	_glow_box(root, Vector3(width, height, 0.12), Color(0.95, 0.9, 0.7), Vector3.ZERO)
	HouseParts.box(root, Vector3(0.08, height, 0.16), WOOD_DARK, Vector3.ZERO)
	HouseParts.box(root, Vector3(width, 0.08, 0.14), WOOD_DARK, Vector3.ZERO)
	HouseParts.box(root, Vector3(width + 0.5, 0.1, 0.3), WOOD, Vector3(0, -height * 0.5 - 0.2, 0.1))   # sill
	_light(root, Color(1.0, 0.92, 0.75), 0.9, 6.0, Vector3(0, 0, 1.2))
	return root

static func toon_mat(color: Color) -> ShaderMaterial:
	return HouseParts.toon(color)

# ---------------------------------------------------------------- furniture

## A round dining table with plates, a loaf, a fruit bowl and a candle.
static func table(radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Table"
	HouseParts.cylinder(root, radius, 0.12, WOOD, Vector3(0, 1.0, 0))
	HouseParts.cylinder(root, radius * 0.18, 0.95, WOOD_DARK, Vector3(0, 0.5, 0))
	HouseParts.cylinder(root, radius * 0.55, 0.1, WOOD_DARK, Vector3(0, 0.05, 0))
	for a in 2:
		var angle := a * PI + 0.6
		HouseParts.cylinder(root, 0.17, 0.03, Color(0.92, 0.92, 0.88), Vector3(cos(angle) * 0.5, 1.07, sin(angle) * 0.5))
	HouseParts.box(root, Vector3(0.32, 0.12, 0.16), Color(0.82, 0.58, 0.3), Vector3(-0.15, 1.12, -0.05), Vector3(0, 25, 0))   # loaf
	HouseParts.cylinder(root, 0.16, 0.1, WOOD_DARK, Vector3(0.12, 1.11, 0.05))   # fruit bowl
	for f in 3:
		_sphere(root, 0.06, toon_mat([Color(0.8, 0.25, 0.2), Color(0.85, 0.7, 0.2), Color(0.5, 0.7, 0.25)][f]), Vector3(0.12 + (f - 1) * 0.07, 1.2, 0.05 + (f % 2) * 0.04))
	root.add_child(candle(Vector3(0.0, 1.06, -0.3)))
	solid(root, Vector3(radius * 2.0, 1.1, radius * 2.0), Vector3(0, 0.55, 0))
	return root

static func candle(pos: Vector3, lights := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Candle"
	root.position = pos
	HouseParts.cylinder(root, 0.07, 0.3, PARCHMENT, Vector3(0, 0.15, 0))
	_cone(root, 0.05, 0.14, glow(FLAME), Vector3(0, 0.37, 0))
	if lights:
		_light(root, FLAME, 0.7, 4.0, Vector3(0, 0.6, 0), 0.15)
	return root

static func stool() -> Node3D:
	var root := Node3D.new()
	root.name = "Stool"
	HouseParts.cylinder(root, 0.3, 0.1, WOOD, Vector3(0, 0.6, 0))
	for a in 3:
		var angle := a * TAU / 3.0
		HouseParts.box(root, Vector3(0.08, 0.6, 0.08), WOOD_DARK, Vector3(cos(angle) * 0.18, 0.3, sin(angle) * 0.18))
	return root

## A treasure chest with gold bands and a gentle glow where the lid meets the body.
static func chest() -> Node3D:
	var root := Node3D.new()
	root.name = "Chest"
	HouseParts.box(root, Vector3(1.3, 0.7, 0.8), WOOD, Vector3(0, 0.35, 0))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.4
	lid.bottom_radius = 0.4
	lid.height = 1.3
	lid.radial_segments = 12
	_mesh(root, lid, toon_mat(WOOD_DARK), Vector3(0, 0.72, 0), Vector3(0, 0, 90))
	for sx in [-0.45, 0.45]:
		HouseParts.box(root, Vector3(0.12, 0.75, 0.84), GOLD, Vector3(sx, 0.37, 0))
	HouseParts.box(root, Vector3(0.18, 0.22, 0.06), GOLD, Vector3(0, 0.62, 0.42))
	_glow_box(root, Vector3(1.2, 0.04, 0.08), Color(1.0, 0.9, 0.5), Vector3(0, 0.71, 0.4))
	solid(root, Vector3(1.3, 1.1, 0.8), Vector3(0, 0.55, 0))
	return root

## A tall wardrobe with two doors.
static func wardrobe() -> Node3D:
	var root := Node3D.new()
	root.name = "Wardrobe"
	HouseParts.box(root, Vector3(1.8, 3.2, 0.8), WOOD, Vector3(0, 1.6, 0))
	HouseParts.box(root, Vector3(2.0, 0.15, 0.95), WOOD_DARK, Vector3(0, 3.27, 0))
	HouseParts.box(root, Vector3(0.82, 2.8, 0.06), WOOD_DARK, Vector3(-0.44, 1.65, 0.4))
	HouseParts.box(root, Vector3(0.82, 2.8, 0.06), WOOD_DARK, Vector3(0.44, 1.65, 0.4))
	for sx in [-0.12, 0.12]:
		HouseParts.cylinder(root, 0.04, 0.12, GOLD, Vector3(sx, 1.6, 0.46))
	solid(root, Vector3(1.8, 3.2, 0.8), Vector3(0, 1.6, 0))
	return root

## A leafy potted plant.
static func plant() -> Node3D:
	var root := Node3D.new()
	root.name = "Plant"
	HouseParts.cylinder(root, 0.3, 0.5, Color(0.72, 0.42, 0.3), Vector3(0, 0.25, 0))
	for a in 7:
		var angle := a * TAU / 7.0
		_cone(root, 0.14, 1.0 + (a % 3) * 0.25, toon_mat(LEAF.lerp(Color(0.5, 0.75, 0.3), (a % 2) * 0.4)), Vector3(cos(angle) * 0.2, 0.95, sin(angle) * 0.2), Vector3(sin(angle) * 20, 0, -cos(angle) * 20))
	solid(root, Vector3(0.7, 1.6, 0.7), Vector3(0, 0.8, 0))
	return root

# -------------------------------------------------------------- hanging light

## A candle ring hanging from the ceiling (origin at the ceiling).
static func chandelier(drop: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Chandelier"
	HouseParts.cylinder(root, 0.03, drop, IRON, Vector3(0, -drop * 0.5, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.7
	ring.outer_radius = 0.8
	_mesh(root, ring, toon_mat(GOLD), Vector3(0, -drop, 0))
	for a in 6:
		var angle := a * TAU / 6.0
		root.add_child(candle(Vector3(cos(angle) * 0.75, -drop + 0.02, sin(angle) * 0.75), false))   # the lamp below lights the room
	_light(root, Color(1.0, 0.85, 0.6), 1.2, 9.0, Vector3(0, -drop - 0.3, 0), 0.15)
	return root

## Dust motes and tiny sparks drifting through the air of the whole room.
static func floating_motes(extent: Vector3) -> CPUParticles3D:
	var p := _sparkles(Color(1.0, 0.92, 0.6), 24, 6.0, 0.06, 0.12)
	p.name = "Motes"
	p.direction = Vector3(0.3, 1.0, 0.2)
	p.spread = 60.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	return p
