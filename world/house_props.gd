@tool
class_name HouseProps
extends RefCounted
## Everyday town props built from simple shapes with the project's toon look: a hanging lantern, a laundry line, bunting, a market
## stall, crates and barrels, a wood pile, a notice board, a bucket and wind chimes. Companion to
## HouseParts (roof/door pieces); like it, every builder returns a Node3D the caller
## positions, and nothing here knows about houses — see HouseExtras for who gets what.
##
## Conventions: a wall-mounted part has its back on z = 0 and sticks out toward +Z; a
## ground part stands on y = 0. Lit parts carry a NightLamp (glow after dusk), cloth
## parts a ClothSway (flutter with the wind).

const CLOTH: Shader = preload("res://shading/cloth_wind.gdshader")

const WARM_LIGHT := Color(1.0, 0.72, 0.4)
const ROOF_RED := Color(0.745, 0.2, 0.12)
const CREAM := Color(0.95, 0.9, 0.78)
const BUNTING_COLORS: Array[Color] = [ROOF_RED, CREAM, Color(0.25, 0.45, 0.7), Color(0.95, 0.75, 0.25)]
const LAUNDRY_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.9), Color(0.5, 0.65, 0.85), Color(0.9, 0.55, 0.5), Color(0.9, 0.82, 0.45), Color(0.7, 0.8, 0.6),
]
const CHIME_SFX: Array[String] = [
	"res://sounds/SFX/others/chime_1.ogg", "res://sounds/SFX/others/chime_2.ogg",
	"res://sounds/SFX/others/chime_3.ogg", "res://sounds/SFX/others/chime_4.ogg",
]

# ----------------------------------------------------------------- helpers

static func _sphere(parent: Node3D, radius: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = HouseParts.toon(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

## A flat piece of cloth (hangs from its top edge) or a pennant (`tip_up`: the point is at the
## top of the mesh, so it is rotated to hang point-down by the caller). Flutters via ClothSway.
static func _cloth_material(color: Color, height: float, tip_up: bool, sway: float, phase: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLOTH
	m.set_shader_parameter(&"albedo_color", color)
	m.set_shader_parameter(&"cloth_h", height)
	m.set_shader_parameter(&"tip_up", tip_up)
	m.set_shader_parameter(&"sway", sway)
	m.set_shader_parameter(&"phase", phase)
	return m

static func _cloth_sheet(parent: Node3D, size: Vector2, color: Color, pos: Vector3, phase: float, sway := 0.1) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.subdivide_depth = 4
	mesh.subdivide_width = 2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _cloth_material(color, size.y, false, sway, phase)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## A thin rope between two points.
static func _rope(parent: Node3D, from: Vector3, to: Vector3, color := Color(0.35, 0.28, 0.2), thickness := 0.025) -> void:
	var length := from.distance_to(to)
	var mi := HouseParts.box(parent, Vector3(thickness, thickness, length), color, (from + to) * 0.5)
	mi.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)   # not in the tree yet, so no look_at()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _lamp_root(parent: Node3D) -> NightLamp:
	var lamp := NightLamp.new()
	lamp.name = "NightLamp"
	lamp.auto_collect = false
	parent.add_child(lamp)
	return lamp

static func _glow_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.4
	m.emission_enabled = true   # also keeps WorldToon from swapping it for the plain toon look
	m.emission = WARM_LIGHT
	m.emission_energy_multiplier = 0.0
	return m

static func _glow_light(parent: Node3D, pos: Vector3, energy: float, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = WARM_LIGHT
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.6
	l.light_specular = 0.0
	l.shadow_enabled = false
	l.position = pos
	parent.add_child(l)
	return l

## A lantern on a wall bracket: origin 0.3 m inside the wall, hangs 0.4 out; mount it sunk 0.3 m into the wall (as the hanging sign is). Glows and lights after dusk.
static func lantern() -> Node3D:
	var root := Node3D.new()
	root.name = "Lantern"
	var iron := HouseParts.IRON
	HouseParts.box(root, Vector3(0.05, 0.05, 0.4), iron, Vector3(0, 0, 0.2))            # arm (its first 0.3 m is inside the wall, like the sign's rod)
	HouseParts.box(root, Vector3(0.05, 0.3, 0.05), iron, Vector3(0, -0.12, 0.05))       # wall plate
	# the lantern hangs from the arm's tip and swings on it (see SwingingSign): the wind pushes it
	# out from the wall, someone running past sets it rocking
	var pivot := SwingingSign.new()
	pivot.name = "Swing"
	pivot.position = Vector3(0, 0, 0.4)
	root.add_child(pivot)
	HouseParts.box(pivot, Vector3(0.02, 0.12, 0.02), iron, Vector3(0, -0.06, 0))        # hook
	var body := Node3D.new()
	body.position = Vector3(0, -0.34, 0)
	pivot.add_child(body)
	HouseParts.box(body, Vector3(0.26, 0.05, 0.26), iron, Vector3(0, 0.17, 0))          # lid
	HouseParts.box(body, Vector3(0.18, 0.06, 0.18), iron, Vector3(0, 0.22, 0))
	HouseParts.box(body, Vector3(0.24, 0.04, 0.24), iron, Vector3(0, -0.17, 0))         # base
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			HouseParts.box(body, Vector3(0.03, 0.34, 0.03), iron, Vector3(cx * 0.11, 0, cz * 0.11))   # cage bars
	var glass := _glow_material(Color(0.9, 0.85, 0.7))
	var pane := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.17, 0.3, 0.17)
	pane.mesh = mesh
	pane.material_override = glass
	body.add_child(pane)
	var lamp := _lamp_root(root)
	lamp.flicker = 0.18
	lamp.add_material(glass, 3.4)
	lamp.add_light(_glow_light(body, Vector3(0, 0, 0.4), 1.6, 7.0), 1.6)   # the light swings with the lantern
	return root

# --------------------------------------------------------------------- cloth

## Laundry on a line: two poles `length` apart along +X (origin at the first pole's foot),
## a rope that sags a little, and a few pieces of cloth fluttering in the wind.
static func laundry_line(length := 3.4, pieces := 4) -> Node3D:
	var root := Node3D.new()
	root.name = "LaundryLine"
	var top := 2.2
	for x in [0.0, length]:
		HouseParts.box(root, Vector3(0.09, top + 0.15, 0.09), HouseParts.WOOD_DARK, Vector3(x, (top + 0.15) * 0.5 - 0.05, 0))
	var sag := 0.14
	var steps := 8
	var prev := Vector3(0, top, 0)
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := Vector3(length * t, top - sag * (1.0 - pow(2.0 * t - 1.0, 2.0)), 0)
		_rope(root, prev, p)
		prev = p
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 100.0)
	for i in pieces:
		var t := (float(i) + 0.5) / pieces
		var w := rng.randf_range(0.42, 0.7)
		var h := rng.randf_range(0.5, 0.85)
		var y := top - sag * (1.0 - pow(2.0 * t - 1.0, 2.0)) - h * 0.5 - 0.02
		_cloth_sheet(root, Vector2(w, h), LAUNDRY_COLORS[rng.randi() % LAUNDRY_COLORS.size()], Vector3(length * t, y, 0), rng.randf() * TAU, 0.12)
	var sway := ClothSway.new()
	sway.name = "ClothSway"
	root.add_child(sway)
	return root

## A string of pennants hung between (0, 0, 0) and (`length`, 0, 0), sagging in the middle.
static func bunting(length := 4.6, count := 11) -> Node3D:
	var root := Node3D.new()
	root.name = "Bunting"
	var sag := 0.35
	var steps := count + 1
	var prev := Vector3.ZERO
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := Vector3(length * t, -sag * (1.0 - pow(2.0 * t - 1.0, 2.0)), 0)
		_rope(root, prev, p, Color(0.3, 0.25, 0.2), 0.02)
		prev = p
	for i in count:
		var t := (float(i) + 0.5) / count
		var color := BUNTING_COLORS[i % BUNTING_COLORS.size()]
		var prism := PrismMesh.new()
		prism.size = Vector3(0.3, 0.38, 0.02)
		var mi := MeshInstance3D.new()
		mi.mesh = prism
		mi.material_override = _cloth_material(color, 0.38, true, 0.07, float(i) * 0.9)
		mi.rotation.z = PI   # point down
		mi.position = Vector3(length * t, -sag * (1.0 - pow(2.0 * t - 1.0, 2.0)) - 0.2, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var sway := ClothSway.new()
	sway.name = "ClothSway"
	root.add_child(sway)
	return root

# ------------------------------------------------------------- market and yard

## A little market stall: a counter with produce, four posts and a striped cloth roof.
## Origin on the ground at the middle of the counter; the customer side is +Z.
## Solid (a box around the counter) so the player can't walk through the goods.
static func stall(width := 3.0, stripe_a := ROOF_RED, stripe_b := CREAM) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Stall"
	var depth := 1.3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.0, 0.7)
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0)
	root.add_child(shape)
	HouseParts.box(root, Vector3(width, 0.9, 0.7), HouseParts.WOOD_LIGHT, Vector3(0, 0.45, 0))
	HouseParts.box(root, Vector3(width + 0.1, 0.07, 0.8), HouseParts.WOOD_DARK, Vector3(0, 0.93, 0))
	for sx in [-1.0, 1.0]:
		HouseParts.box(root, Vector3(0.09, 2.6, 0.09), HouseParts.WOOD_DARK, Vector3(sx * (width * 0.5 - 0.05), 1.3, -0.3))   # back posts
		HouseParts.box(root, Vector3(0.09, 2.2, 0.09), HouseParts.WOOD_DARK, Vector3(sx * (width * 0.5 - 0.05), 1.1, 0.5))    # front posts, shorter: the roof slopes
	var stripes := 8
	var sw := width / stripes
	var slope := atan2(0.4, depth + 0.2)
	for i in stripes:
		var piece := HouseParts.box(root, Vector3(sw, 0.05, depth + 0.5), stripe_a if i % 2 == 0 else stripe_b,
				Vector3(-width * 0.5 + sw * (i + 0.5), 2.46, 0.1), Vector3(rad_to_deg(slope), 0, 0))
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i in stripes:   # scalloped valance that flutters
		var color := stripe_a if i % 2 == 0 else stripe_b
		_cloth_sheet(root, Vector2(sw, 0.28), color, Vector3(-width * 0.5 + sw * (i + 0.5), 2.18, 0.58), float(i), 0.04)
	# goods on the counter: crates of apples, pears and loaves
	var goods := [[Color(0.82, 0.18, 0.15), -0.9], [Color(0.7, 0.8, 0.25), 0.0], [Color(0.85, 0.6, 0.3), 0.9]]
	for g in goods:
		var x: float = g[1] * width / 3.0
		HouseParts.box(root, Vector3(0.7, 0.16, 0.45), HouseParts.WOOD_DARK, Vector3(x, 1.05, 0.0))
		for k in 7:
			_sphere(root, 0.09, g[0], Vector3(x + (k % 4 - 1.5) * 0.14, 1.19 + (0.05 if k > 3 else 0.0), (k / 4 - 0.5) * 0.18))
	var sway := ClothSway.new()
	sway.name = "ClothSway"
	root.add_child(sway)
	return root

## Crates and a couple of barrels in a cluster: origin on the ground; spreads about 1.4 m along +X.
static func crates_and_barrels() -> Node3D:
	var root := Node3D.new()
	root.name = "CratesAndBarrels"
	var wood := HouseParts.WOOD_LIGHT
	HouseParts.box(root, Vector3(0.7, 0.6, 0.6), wood, Vector3(0.35, 0.3, 0.0))
	HouseParts.box(root, Vector3(0.55, 0.5, 0.5), wood.darkened(0.12), Vector3(0.3, 0.85, 0.02), Vector3(0, 14, 0))
	HouseParts.box(root, Vector3(0.65, 0.55, 0.6), wood.darkened(0.05), Vector3(1.05, 0.275, 0.1), Vector3(0, -9, 0))
	for p in [Vector3(1.0, 0, 0.75), Vector3(1.55, 0, 0.35)]:
		var barrel := HouseParts.cylinder(root, 0.34, 0.85, HouseParts.WOOD_DARK, p + Vector3(0, 0.425, 0))
		for y in [-0.25, 0.25]:
			var band := HouseParts.cylinder(root, 0.355, 0.06, HouseParts.IRON, p + Vector3(0, 0.425 + y, 0))
			band.name = "Band"
		barrel.name = "Barrel"
	var body := StaticBody3D.new()   # one solid block around the cluster
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.9, 1.5)
	shape.shape = box
	shape.position = Vector3(0.85, 0.45, 0.3)
	body.add_child(shape)
	root.add_child(body)
	Smashable.make(body, &"prop_crate")   # smash it with a pound, dive or roll
	return root

## A stack of split logs with a chopping stump and axe: origin on the ground, the pile runs along +X.
static func wood_pile() -> Node3D:
	var root := Node3D.new()
	root.name = "WoodPile"
	var rows := [5, 4, 3]
	for r in rows.size():
		for i in rows[r]:
			var log := HouseParts.cylinder(root, 0.12, 1.3, HouseParts.WOOD_LIGHT.darkened(0.08 * ((i + r) % 3)),
					Vector3(0.14 + i * 0.25 + r * 0.125, 0.12 + r * 0.21, 0))
			log.rotation_degrees.x = 90.0
	var stump := HouseParts.cylinder(root, 0.26, 0.5, HouseParts.WOOD_DARK, Vector3(1.9, 0.25, 0.5))
	stump.name = "Stump"
	HouseParts.box(root, Vector3(0.05, 0.6, 0.05), HouseParts.WOOD_DARK, Vector3(1.9, 0.78, 0.5), Vector3(18, 0, 14))   # axe handle
	HouseParts.box(root, Vector3(0.05, 0.14, 0.2), HouseParts.IRON, Vector3(1.95, 1.0, 0.57), Vector3(18, 0, 14))      # axe head
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.7, 1.35)
	shape.shape = box
	shape.position = Vector3(0.7, 0.35, 0)
	body.add_child(shape)
	root.add_child(body)
	return root

## A notice board on two posts. `notes` is [{text, show_when: [flags], hide_when: flag}]:
## each paper is only pinned while its flags say so (FlagVisibility), so the board
## reflects the story — "LOST CAT" until the cat is found, then "THANK YOU". Faces +Z.
static func notice_board(notes: Array) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "NoticeBoard"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.2, 0.3)
	shape.shape = box
	shape.position = Vector3(0, 1.5, 0)
	root.add_child(shape)
	for sx in [-0.85, 0.85]:
		HouseParts.box(root, Vector3(0.12, 2.2, 0.12), HouseParts.WOOD_DARK, Vector3(sx, 1.1, 0))
	HouseParts.box(root, Vector3(1.95, 1.25, 0.08), HouseParts.WOOD_DARK, Vector3(0, 1.55, 0.0))
	HouseParts.box(root, Vector3(1.8, 1.1, 0.1), Color(0.55, 0.4, 0.28), Vector3(0, 1.55, 0.02))
	HouseParts.box(root, Vector3(2.15, 0.1, 0.3), HouseParts.WOOD_DARK, Vector3(0, 2.25, 0.05), Vector3(0, 0, 0))   # little roof
	var slots := [Vector3(-0.5, 1.7, 0.1), Vector3(0.45, 1.75, 0.1), Vector3(-0.45, 1.3, 0.1), Vector3(0.5, 1.3, 0.1)]
	for i in mini(notes.size(), slots.size()):
		var note: Dictionary = notes[i]
		var paper := Node3D.new()
		paper.name = "Note%d" % i
		paper.position = slots[i]
		paper.rotation_degrees.z = (i % 2 * 2 - 1) * 3.0
		HouseParts.box(paper, Vector3(0.7, 0.5, 0.02), Color(0.95, 0.92, 0.8), Vector3.ZERO)
		HouseParts.box(paper, Vector3(0.05, 0.05, 0.03), Color(0.7, 0.15, 0.15), Vector3(0, 0.22, 0.01))   # pin
		var label := Label3D.new()
		label.text = String(note["text"])
		label.font_size = 28
		label.pixel_size = 0.0028
		label.modulate = Color(0.2, 0.12, 0.08)
		label.outline_size = 0
		label.shaded = false
		label.double_sided = false
		label.position = Vector3(0, -0.02, 0.025)
		paper.add_child(label)
		var gate := FlagVisibility.new()
		gate.name = "FlagVisibility"
		var shown: Array[StringName] = []
		for f in note.get("show_when", []):
			shown.append(StringName(f))
		gate.show_when = shown
		gate.hide_when = StringName(note.get("hide_when", ""))
		paper.add_child(gate)
		root.add_child(paper)
	return root

## A wooden bucket with an iron band, a rope handle, water inside and a coil of rope beside it:
## origin on the ground, about 0.8 m across. Not solid, so nobody snags on it.
static func bucket() -> Node3D:
	var root := Node3D.new()
	root.name = "Bucket"
	var staves := CylinderMesh.new()   # a little wider at the top, like a real bucket
	staves.top_radius = 0.2
	staves.bottom_radius = 0.16
	staves.height = 0.34
	staves.radial_segments = 14
	HouseParts._part(root, staves, HouseParts.WOOD_LIGHT.darkened(0.1), Vector3(0, 0.17, 0))
	HouseParts.cylinder(root, 0.188, 0.05, HouseParts.IRON, Vector3(0, 0.1, 0)).name = "BandLow"
	HouseParts.cylinder(root, 0.2, 0.05, HouseParts.IRON, Vector3(0, 0.29, 0)).name = "BandHigh"
	HouseParts.cylinder(root, 0.175, 0.02, Color(0.2, 0.38, 0.5), Vector3(0, 0.3, 0)).name = "Water"
	var handle := TorusMesh.new()   # the rope handle, flopped over to one side
	handle.inner_radius = 0.17
	handle.outer_radius = 0.19
	var h := HouseParts._part(root, handle, Color(0.45, 0.36, 0.24), Vector3(0, 0.36, 0), Vector3(90, 0, 0))
	h.name = "Handle"
	h.scale = Vector3(1.0, 1.0, 0.6)
	var coil := TorusMesh.new()   # a coil of rope on the ground
	coil.inner_radius = 0.08
	coil.outer_radius = 0.17
	var c := HouseParts._part(root, coil, Color(0.5, 0.4, 0.27), Vector3(0.45, 0.03, 0.1))
	c.name = "RopeCoil"
	c.scale = Vector3(1.0, 0.35, 1.0)
	return root

## A fallen adventurer's remains: a skull, a few long bones and a ribcage, flat on the ground. Origin on the
## ground, about 1 m across, not solid. For the well and other dark places.
static func bone_pile() -> Node3D:
	var root := Node3D.new()
	root.name = "BonePile"
	var bone := Color(0.86, 0.83, 0.72)
	var skull := HouseParts._part(root, SphereMesh.new(), bone, Vector3(0.28, 0.13, 0.05))
	(skull.mesh as SphereMesh).radius = 0.13
	(skull.mesh as SphereMesh).height = 0.26
	skull.name = "Skull"
	skull.scale = Vector3(1.0, 0.9, 1.1)
	for side in [-1.0, 1.0]:   # eye sockets
		var eye := HouseParts._part(root, SphereMesh.new(), Color(0.08, 0.07, 0.06), Vector3(0.28 + side * 0.05, 0.16, 0.16))
		(eye.mesh as SphereMesh).radius = 0.03
		(eye.mesh as SphereMesh).height = 0.06
		eye.name = "EyeSocket"
	var jaw := HouseParts.box(root, Vector3(0.16, 0.04, 0.1), bone.darkened(0.08), Vector3(0.28, 0.04, 0.13))
	jaw.name = "Jaw"
	for i in 5:   # ribs: arcs lying on their side, getting shorter toward the bottom
		var rib := TorusMesh.new()
		rib.inner_radius = 0.2 - i * 0.02
		rib.outer_radius = rib.inner_radius + 0.03
		var r := HouseParts._part(root, rib, bone, Vector3(-0.2 - i * 0.1, 0.1, -0.05 + i * 0.015), Vector3(0, 0, 90))
		r.scale = Vector3(1.0, 1.0, 0.7)
		r.name = "Rib%d" % i
	var spine := HouseParts.box(root, Vector3(0.56, 0.05, 0.05), bone, Vector3(-0.42, 0.04, -0.04), Vector3(0, 6, 0))
	spine.name = "Spine"
	for b in [[Vector3(0.1, 0.03, -0.32), 38.0, 0.5], [Vector3(0.4, 0.03, -0.18), -20.0, 0.42], [Vector3(-0.5, 0.03, 0.32), 80.0, 0.46]]:
		var long := HouseParts.cylinder(root, 0.025, b[2], bone, b[0])   # a long bone, laid flat
		long.rotation_degrees = Vector3(0, b[1], 90)
		long.name = "LongBone"
	return root

## Rope and planks: a coil of old rope, a loose tail of it and a few broken planks, one propped on
## another. Origin on the ground, about 1.2 m across, not solid. For the well and other dark places.
static func rope_and_planks() -> Node3D:
	var root := Node3D.new()
	root.name = "RopeAndPlanks"
	var rope := Color(0.5, 0.4, 0.27)
	for i in 3:   # the coil: a few turns stacked
		var turn := TorusMesh.new()
		turn.inner_radius = 0.12 - i * 0.015
		turn.outer_radius = turn.inner_radius + 0.045
		var t := HouseParts._part(root, turn, rope, Vector3(0.35, 0.025 + i * 0.04, 0.1))
		t.name = "Coil%d" % i
	HouseParts.cylinder(root, 0.02, 0.5, rope, Vector3(0.08, 0.02, 0.28)).rotation_degrees = Vector3(0, 20, 90)   # the loose tail
	var wood := HouseParts.WOOD_DARK
	HouseParts.box(root, Vector3(0.9, 0.04, 0.16), wood, Vector3(-0.3, 0.02, -0.1), Vector3(0, 12, 0)).name = "Plank1"
	HouseParts.box(root, Vector3(0.7, 0.04, 0.15), wood.darkened(0.12), Vector3(-0.2, 0.06, -0.3), Vector3(0, -18, 0)).name = "Plank2"
	HouseParts.box(root, Vector3(0.6, 0.04, 0.14), wood.lightened(0.08), Vector3(-0.55, 0.12, -0.25), Vector3(0, 35, 14)).name = "Plank3"   # propped up
	HouseParts.box(root, Vector3(0.05, 0.05, 0.2), HouseParts.IRON, Vector3(-0.72, 0.045, -0.08)).name = "Nail"
	return root

## A smashed barrel and a broken clay pot with its spilled grain: a ring of fallen staves, a few
## shards. Origin on the ground, about 1.3 m across, not solid.
static func broken_pots() -> Node3D:
	var root := Node3D.new()
	root.name = "BrokenPots"
	var wood := HouseParts.WOOD_LIGHT.darkened(0.15)
	HouseParts.cylinder(root, 0.26, 0.05, wood.darkened(0.15), Vector3(-0.3, 0.025, 0.0)).name = "BarrelBase"
	for i in 6:   # staves still standing at the back of the base, the rest burst outward
		var a := TAU * float(i) / 6.0
		var stave := HouseParts.box(root, Vector3(0.07, 0.4 - i * 0.05, 0.03), wood, Vector3(-0.3 + cos(a) * 0.24, 0.17 - i * 0.02, sin(a) * 0.24), Vector3(0, -rad_to_deg(a), 6.0 + float(i) * 12.0))
		stave.name = "Stave%d" % i
	HouseParts.box(root, Vector3(0.5, 0.03, 0.07), wood, Vector3(-0.1, 0.02, 0.42), Vector3(0, 25, 0)).name = "FallenStave"
	HouseParts.cylinder(root, 0.03, 0.5, HouseParts.IRON, Vector3(-0.5, 0.025, -0.4)).rotation_degrees = Vector3(0, 40, 90)   # a loose hoop piece
	var clay := Color(0.7, 0.4, 0.26)
	var pot := SphereMesh.new()
	pot.radius = 0.18
	pot.height = 0.32
	var p := HouseParts._part(root, pot, clay, Vector3(0.45, 0.12, -0.05), Vector3(0, 0, 70))   # tipped on its side
	p.name = "Pot"
	var neck := HouseParts.cylinder(root, 0.07, 0.1, clay.darkened(0.1), Vector3(0.6, 0.12, -0.05))
	neck.rotation_degrees = Vector3(0, 0, 90)
	neck.name = "PotNeck"
	HouseParts.cylinder(root, 0.2, 0.012, Color(0.82, 0.72, 0.45), Vector3(0.28, 0.008, 0.1)).name = "SpilledGrain"
	for i in 4:   # shards
		HouseParts.box(root, Vector3(0.09, 0.015, 0.06), clay.darkened(0.05 * i), Vector3(0.1 + i * 0.12, 0.012, 0.28 - i * 0.08), Vector3(0, 30.0 + i * 55.0, 0)).name = "Shard%d" % i
	return root

## A lantern knocked over and still burning: iron cage lying on its side, a warm dim glow and a little
## light on the floor around it. Origin on the ground, not solid. Meant for places where it is dark.
static func dropped_lantern() -> Node3D:
	var root := Node3D.new()
	root.name = "DroppedLantern"
	var iron := HouseParts.IRON
	var body := Node3D.new()
	body.position = Vector3(0, 0.13, 0)
	body.rotation_degrees = Vector3(0, 25, 82)   # on its side
	root.add_child(body)
	HouseParts.box(body, Vector3(0.26, 0.05, 0.26), iron, Vector3(0, 0.17, 0))
	HouseParts.box(body, Vector3(0.18, 0.06, 0.18), iron, Vector3(0, 0.22, 0))
	HouseParts.box(body, Vector3(0.24, 0.04, 0.24), iron, Vector3(0, -0.17, 0))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			HouseParts.box(body, Vector3(0.03, 0.34, 0.03), iron, Vector3(cx * 0.11, 0, cz * 0.11))
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color(1.0, 0.82, 0.5)
	var pane := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.17, 0.3, 0.17)
	pane.mesh = mesh
	pane.material_override = flame
	body.add_child(pane)
	var arc := TorusMesh.new()   # the carry handle
	arc.inner_radius = 0.1
	arc.outer_radius = 0.115
	var handle := HouseParts._part(body, arc, iron, Vector3(0, 0.27, 0), Vector3(90, 0, 0))
	handle.scale = Vector3(1.0, 1.0, 0.8)
	handle.name = "Handle"
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.7, 0.35)
	glow.light_energy = 0.9
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0.3, 0)
	glow.shadow_enabled = false
	root.add_child(glow)
	return root

## Wind chimes: a ring with hanging tubes that swing and tinkle when a gust rises (WindChimes).
static func wind_chimes() -> Node3D:
	var chimes := WindChimes.new()
	chimes.name = "WindChimes"
	HouseParts.box(chimes, Vector3(0.05, 0.05, 0.3), HouseParts.IRON, Vector3(0, 0, 0.15))
	var swing := Node3D.new()
	swing.name = "Swing"
	swing.position = Vector3(0, 0, 0.3)
	chimes.add_child(swing)
	HouseParts.cylinder(swing, 0.14, 0.03, HouseParts.WOOD_DARK, Vector3(0, -0.2, 0))
	var lengths := [0.34, 0.26, 0.42, 0.3, 0.22]
	for i in lengths.size():
		var a := TAU * float(i) / lengths.size()
		var tube := HouseParts.cylinder(swing, 0.018, lengths[i], Color(0.8, 0.82, 0.88), Vector3(cos(a) * 0.1, -0.22 - lengths[i] * 0.5, sin(a) * 0.1))
		tube.name = "Tube%d" % i
	HouseParts.cylinder(swing, 0.05, 0.02, HouseParts.WOOD_LIGHT, Vector3(0, -0.5, 0))   # clapper plate
	return chimes
