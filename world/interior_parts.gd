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
const POTION_COLORS: Array[Color] = [
	Color(0.9, 0.25, 0.35), Color(0.3, 0.8, 0.95), Color(0.5, 0.95, 0.4), Color(0.75, 0.4, 0.95), Color(1.0, 0.8, 0.3),
]
enum Fill { BOOKS, POTIONS }

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
	HouseParts.box(root, Vector3(3.4, 0.25, 1.6), STONE_DARK, Vector3(0, 0.125, 0.3))       # hearth slab
	HouseParts.box(root, Vector3(0.8, 3.2, 1.0), STONE, Vector3(-1.3, 1.6, 0.0))            # left pillar
	HouseParts.box(root, Vector3(0.8, 3.2, 1.0), STONE, Vector3(1.3, 1.6, 0.0))             # right pillar
	HouseParts.box(root, Vector3(3.4, 0.7, 1.1), STONE, Vector3(0, 2.85, 0.0))              # lintel
	HouseParts.box(root, Vector3(3.8, 0.2, 1.4), WOOD_DARK, Vector3(0, 3.3, 0.1))           # mantle
	HouseParts.box(root, Vector3(1.8, 2.5, 0.3), Color(0.08, 0.06, 0.06), Vector3(0, 1.4, -0.4))   # sooty back
	HouseParts.cylinder(root, 0.16, 1.3, WOOD_DARK, Vector3(0, 0.45, 0.0)).rotation_degrees = Vector3(0, 0, 90)
	HouseParts.cylinder(root, 0.14, 1.1, WOOD, Vector3(0.0, 0.62, 0.0)).rotation_degrees = Vector3(90, 0, 25)
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

## A tall shelf (back panel, uprights, boards) full of books or glowing potions.
static func shelf(width: float, height: float, fill: int, seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Shelf"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var depth := 0.6
	HouseParts.box(root, Vector3(width, height, 0.1), WOOD_DARK, Vector3(0, height * 0.5, -depth * 0.5 + 0.05))
	for sx in [-1.0, 1.0]:
		HouseParts.box(root, Vector3(0.12, height, depth), WOOD, Vector3(sx * (width * 0.5 - 0.06), height * 0.5, 0))
	HouseParts.box(root, Vector3(width + 0.1, 0.12, depth + 0.1), WOOD, Vector3(0, height + 0.06, 0))   # crown
	var rows := 4 if fill == Fill.BOOKS else 3
	var gap := (height - 0.15) / rows
	for r in rows:
		var y := 0.1 + r * gap
		HouseParts.box(root, Vector3(width - 0.2, 0.1, depth), WOOD, Vector3(0, y, 0))
		if fill == Fill.BOOKS:
			_books(root, rng, width - 0.3, y + 0.05, gap - 0.2)
		else:
			_potions(root, rng, width - 0.3, y + 0.05)
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

static func _potions(root: Node3D, rng: RandomNumberGenerator, span: float, y: float) -> void:
	var x := -span * 0.5 + 0.2
	while x < span * 0.5 - 0.15:
		var color := POTION_COLORS[rng.randi() % POTION_COLORS.size()]
		var r := rng.randf_range(0.09, 0.14)
		var body := CylinderMesh.new()
		body.top_radius = r
		body.bottom_radius = r
		body.height = r * 2.2
		body.radial_segments = 10
		_mesh(root, body, glow(color), Vector3(x, y + r * 1.1, 0.05))
		HouseParts.cylinder(root, r * 0.35, 0.18, Color(0.85, 0.9, 0.95), Vector3(x, y + r * 2.2 + 0.09, 0.05))
		HouseParts.cylinder(root, r * 0.4, 0.06, WOOD, Vector3(x, y + r * 2.2 + 0.2, 0.05))   # cork
		x += r * 2.0 + rng.randf_range(0.12, 0.3)

## A hanging cloth banner with a gold diamond.
static func banner(cloth: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Banner"
	HouseParts.box(root, Vector3(1.3, 0.12, 0.12), GOLD, Vector3(0, 3.0, 0.08))
	HouseParts.box(root, Vector3(1.1, 2.6, 0.05), cloth, Vector3(0, 1.7, 0.05))
	_cone(root, 0.3, 0.4, toon_mat(cloth), Vector3(0, 0.2, 0.05), Vector3(180, 0, 0))   # pointed end
	HouseParts.box(root, Vector3(0.36, 0.36, 0.04), GOLD, Vector3(0, 2.0, 0.1), Vector3(0, 0, 45))
	HouseParts.box(root, Vector3(0.2, 0.2, 0.05), cloth.darkened(0.3), Vector3(0, 2.0, 0.12), Vector3(0, 0, 45))
	return root

static func toon_mat(color: Color) -> ShaderMaterial:
	return HouseParts.toon(color)

# ---------------------------------------------------------------- furniture

## A round table with a candle, a crystal ball and an open spellbook on it.
static func table(radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Table"
	HouseParts.cylinder(root, radius, 0.12, WOOD, Vector3(0, 1.0, 0))
	HouseParts.cylinder(root, radius * 0.18, 0.95, WOOD_DARK, Vector3(0, 0.5, 0))
	HouseParts.cylinder(root, radius * 0.55, 0.1, WOOD_DARK, Vector3(0, 0.05, 0))
	# crystal ball on a gold stand
	HouseParts.cylinder(root, 0.16, 0.08, GOLD, Vector3(-0.2, 1.1, -0.1))
	_sphere(root, 0.22, glow(Color(0.6, 0.85, 1.0, 1.0)), Vector3(-0.2, 1.34, -0.1))
	var wisp := _sparkles(CRYSTAL, 5, 2.0, 0.07, 0.25)
	wisp.position = Vector3(-0.2, 1.4, -0.1)
	root.add_child(wisp)
	_light(root, CRYSTAL, 0.6, 3.5, Vector3(-0.2, 1.5, -0.1))
	# open book
	HouseParts.box(root, Vector3(0.34, 0.05, 0.42), VELVET_DARK, Vector3(0.28, 1.09, 0.12), Vector3(0, 12, 0))
	HouseParts.box(root, Vector3(0.3, 0.04, 0.38), PARCHMENT, Vector3(0.28, 1.12, 0.12), Vector3(0, 12, 0))
	root.add_child(candle(Vector3(0.15, 1.06, -0.3)))
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
	_glow_box(root, Vector3(1.2, 0.04, 0.04), Color(1.0, 0.9, 0.5), Vector3(0, 0.71, 0.4))
	solid(root, Vector3(1.3, 1.1, 0.8), Vector3(0, 0.55, 0))
	return root

## An iron cauldron with a bubbling green brew.
static func cauldron() -> Node3D:
	var root := Node3D.new()
	root.name = "Cauldron"
	_sphere(root, 0.75, toon_mat(IRON), Vector3(0, 0.75, 0), 0.9)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.58
	rim.outer_radius = 0.72
	_mesh(root, rim, toon_mat(IRON.lightened(0.1)), Vector3(0, 1.15, 0))
	HouseParts.cylinder(root, 0.6, 0.04, Color(0, 0, 0), Vector3(0, 1.1, 0)).material_override = glow(Color(0.4, 0.95, 0.35))
	for a in 3:
		var angle := a * TAU / 3.0 + 0.5
		HouseParts.box(root, Vector3(0.14, 0.4, 0.14), IRON, Vector3(cos(angle) * 0.5, 0.2, sin(angle) * 0.5))
	var bubbles := _sparkles(Color(0.5, 1.0, 0.45), 9, 1.4, 0.13, 0.7)
	bubbles.position = Vector3(0, 1.15, 0)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.4
	root.add_child(bubbles)
	_light(root, Color(0.4, 1.0, 0.4), 0.8, 4.5, Vector3(0, 1.8, 0), 0.2)
	solid(root, Vector3(1.4, 1.2, 1.4), Vector3(0, 0.6, 0))
	return root

# -------------------------------------------------------------- magic bits

## A cluster of glowing crystals growing out of the floor.
static func crystals(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Crystals"
	var spec := [
		[Vector3(0, 0, 0), 0.3, 1.8, Vector3(0, 0, 0)],
		[Vector3(0.45, 0, 0.1), 0.2, 1.2, Vector3(0, 0, -22)],
		[Vector3(-0.4, 0, 0.15), 0.22, 1.35, Vector3(0, 0, 20)],
		[Vector3(0.1, 0, -0.4), 0.18, 1.0, Vector3(18, 0, 0)],
	]
	for s in spec:
		var h: float = s[2]
		var holder := Node3D.new()
		holder.position = s[0]
		holder.rotation_degrees = s[3]
		root.add_child(holder)
		_cone(holder, s[1], h, glow(color.lerp(Color.WHITE, randf() * 0.25)), Vector3(0, h * 0.5, 0))
	_light(root, color, 1.0, 6.0, Vector3(0, 1.2, 0.3))
	var motes := _sparkles(color, 6, 2.5, 0.07, 0.4)
	motes.position = Vector3(0, 1.6, 0)
	root.add_child(motes)
	solid(root, Vector3(1.2, 1.8, 1.0), Vector3(0, 0.9, 0))
	return root

## A ring chandelier hanging from the ceiling (origin at the ceiling), with candles and a crystal.
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
	_cone(root, 0.18, 0.5, glow(CRYSTAL), Vector3(0, -drop - 0.25, 0), Vector3(180, 0, 0))
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
