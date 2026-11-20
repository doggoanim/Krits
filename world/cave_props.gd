@tool
class_name CaveProps
extends RefCounted
## Props for the walls and roof of dark places like the well. Built from HouseParts primitives, like
## HouseProps, and placed with PropSlot (the slot's `kind` picks the builder).
##
## Two conventions, so a slot's transform is all a level designer has to set:
##   WALL props  - origin on the wall's surface, local +Z pointing OUT of the wall (into the room),
##                 local +Y up. A ladder is the exception: its origin is on the floor at the wall.
##   ROOF props  - origin on the ceiling, hanging down along -Y.
## None of them are solid. PropSlot's `length` (default 4 m) sizes the ones that hang: how far a rope or
## chain drops, how long roots and stalactites grow, so a prop on a 12 m ceiling can still reach a visible height.

const STONE := Color(0.36, 0.35, 0.4)
const MOSS := Color(0.22, 0.4, 0.2)
const ROOT := Color(0.34, 0.24, 0.16)
const ROPE := Color(0.5, 0.4, 0.27)

# ------------------------------------------------------------------ wall

## An iron bracket holding a burning torch, with a warm light and the game's painted flames.
static func wall_torch() -> Node3D:
	var root := Node3D.new()
	root.name = "WallTorch"
	var iron := HouseParts.IRON
	HouseParts.box(root, Vector3(0.12, 0.3, 0.04), iron, Vector3(0, 0, 0.02))   # wall plate
	HouseParts.box(root, Vector3(0.05, 0.05, 0.28), iron, Vector3(0, -0.05, 0.14))   # arm
	var cup := HouseParts.cylinder(root, 0.07, 0.1, iron, Vector3(0, 0.0, 0.28))   # the cup that holds the torch
	cup.name = "Cup"
	var stick := HouseParts.cylinder(root, 0.035, 0.5, HouseParts.WOOD_DARK, Vector3(0, 0.2, 0.3))
	stick.rotation_degrees = Vector3(-8, 0, 0)
	stick.name = "Stick"
	var flames := FireFx.flame(0.4, 0.22, FireFx.PALETTE_FIRE, 3, randf() * 6.0)
	flames.position = Vector3(0, 0.42, 0.34)
	root.add_child(flames)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.6, 0.6)
	root.add_child(light)
	return root

## Rope and a rusty chain hanging from iron hooks on the wall, ending in a loose coil on the ground.
## Hangs 0.55 x `length` below its origin (2.2 m by default).
static func wall_ropes(length := 4.0) -> Node3D:
	var root := Node3D.new()
	root.name = "WallRopes"
	var iron := HouseParts.IRON
	for x in [-0.18, 0.18]:
		HouseParts.box(root, Vector3(0.1, 0.1, 0.05), iron, Vector3(x, 0, 0.03)).name = "Hook"
		var hook := HouseParts.cylinder(root, 0.015, 0.1, iron, Vector3(x, -0.04, 0.09))
		hook.rotation_degrees = Vector3(90, 0, 0)
	# the rope: a column of short, slightly bent lengths, frayed at the end
	var y := -0.05
	var drop := length * 0.55
	for i in maxi(int(drop / 0.24), 3):
		var seg := HouseParts.cylinder(root, 0.028, 0.25, ROPE, Vector3(-0.18 + sin(i * 0.9) * 0.03, y - 0.125, 0.1 + i * 0.012))
		seg.rotation_degrees = Vector3(0, 0, sin(i * 0.9) * 5.0)
		seg.name = "Rope%d" % i
		y -= 0.24
	# the chain: alternating links, one facing the viewer and the next turned sideways
	y = -0.05
	for i in maxi(int(drop / 0.13) - 3, 3):
		var link := TorusMesh.new()
		link.inner_radius = 0.035
		link.outer_radius = 0.058
		var l := HouseParts._part(root, link, iron.lightened(0.08), Vector3(0.18, y - 0.04, 0.1), Vector3(90, 0 if i % 2 == 0 else 90, 0))
		l.scale = Vector3(1.0, 1.0, 1.7)
		l.name = "Link%d" % i
		y -= 0.13
	return root

## Patches of moss on the stone with a few vines trailing from them. About 1.4 m wide, hangs about 1 m.
static func wall_moss() -> Node3D:
	var root := Node3D.new()
	root.name = "WallMoss"
	var patches := [[Vector3(0, 0, 0), 0.9, 0.55], [Vector3(0.5, -0.1, 0), 0.7, 0.42], [Vector3(-0.5, -0.06, 0), 0.75, 0.46], [Vector3(0.1, -0.32, 0), 0.6, 0.34], [Vector3(-0.15, 0.2, 0), 0.5, 0.3]]
	for i in patches.size():
		var spec: Array = patches[i]
		var blob := SphereMesh.new()
		blob.radius = 0.5
		blob.height = 1.0
		var m := HouseParts._part(root, blob, MOSS.darkened(0.08 * i).lightened(0.05), spec[0] + Vector3(0, 0, 0.01 + 0.004 * i))
		m.scale = Vector3(spec[1], spec[2], 0.04)
		m.name = "Patch%d" % i
	for i in 5:   # vines
		var x := -0.6 + float(i) * 0.3
		var length := 0.4 + 0.45 * absf(sin(float(i) * 2.1))
		var vine := HouseParts.cylinder(root, 0.014, length, MOSS.darkened(0.15), Vector3(x, -0.15 - length * 0.5, 0.03))
		vine.rotation_degrees = Vector3(0, 0, sin(float(i) * 1.7) * 6.0)
		vine.name = "Vine%d" % i
	return root

## A rickety wooden ladder leaning on the wall, with rungs missing and one rail snapped. Its origin is on the
## FLOOR at the foot of the wall; it is about 2 m tall and leans in toward the wall (-Z).
static func wall_ladder() -> Node3D:
	var root := Node3D.new()
	root.name = "WallLadder"
	var wood := HouseParts.WOOD_DARK
	var lean := 12.0
	var tilt := Node3D.new()   # pivots at the foot, so the whole ladder leans together
	tilt.position = Vector3(0, 0, 0.3)
	tilt.rotation_degrees = Vector3(-lean, 0, 0)
	root.add_child(tilt)
	HouseParts.box(tilt, Vector3(0.07, 2.0, 0.06), wood, Vector3(-0.28, 1.0, 0)).name = "RailLeft"
	HouseParts.box(tilt, Vector3(0.07, 1.35, 0.06), wood.darkened(0.1), Vector3(0.28, 0.675, 0)).name = "RailRight"   # snapped off halfway
	HouseParts.box(tilt, Vector3(0.07, 0.3, 0.06), wood.darkened(0.1), Vector3(0.36, 1.2, 0.05), Vector3(0, 0, -38)).name = "RailBroken"   # the broken piece hanging on
	for i in 6:
		if i == 2 or i == 4:
			continue   # missing rungs
		var h := 0.25 + float(i) * 0.31
		HouseParts.box(tilt, Vector3(0.6, 0.05, 0.05), wood.lightened(0.05), Vector3(0, h, 0.0)).name = "Rung%d" % i
	return root

# ------------------------------------------------------------------ roof

## A cluster of rock spikes hanging from the ceiling, the biggest 0.33 x `length` long (1.3 m by default).
static func stalactites(length := 4.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Stalactites"
	root.scale = Vector3.ONE * (length / 4.0)
	var spikes := [[Vector3(0, 0, 0), 0.2, 1.3], [Vector3(0.3, 0, 0.1), 0.13, 0.8], [Vector3(-0.28, 0, -0.08), 0.15, 0.95], [Vector3(0.08, 0, -0.3), 0.09, 0.55], [Vector3(-0.1, 0, 0.3), 0.08, 0.45]]
	for i in spikes.size():
		var spec: Array = spikes[i]
		var cone := CylinderMesh.new()
		cone.top_radius = spec[1]
		cone.bottom_radius = 0.0
		cone.height = spec[2]
		cone.radial_segments = 7
		var s := HouseParts._part(root, cone, STONE.darkened(0.05 * i), spec[0] + Vector3(0, -spec[2] * 0.5 + 0.05, 0), Vector3(0, i * 25.0, 0))
		s.name = "Spike%d" % i
	return root

## Tangled roots poking through the ceiling and dangling, the longest 0.45 x `length` (1.8 m by default).
static func hanging_roots(length := 4.0) -> Node3D:
	var root := Node3D.new()
	root.name = "HangingRoots"
	var clump := SphereMesh.new()
	clump.radius = 0.5
	clump.height = 1.0
	var c := HouseParts._part(root, clump, ROOT.darkened(0.1), Vector3(0, 0.02, 0))
	c.scale = Vector3(0.55, 0.16, 0.55)
	c.name = "Clump"
	for i in 7:
		var a := TAU * float(i) / 7.0
		var strand := (0.5 + 0.5 * absf(sin(float(i) * 1.9))) * length * 0.45
		var base := Vector3(cos(a) * 0.17, 0.0, sin(a) * 0.17)
		var parts := 4
		var y := 0.0
		for k in parts:   # each strand bends a little as it goes down
			var seg := HouseParts.cylinder(root, 0.03 * (1.0 - float(k) / 5.0), strand / parts, ROOT.lightened(0.04 * k),
					base + Vector3(sin(float(i) * 1.3 + k * 0.7) * 0.05 * k, y - strand / parts * 0.5, cos(float(i) * 1.1 + k * 0.7) * 0.05 * k))
			seg.rotation_degrees = Vector3(cos(a) * 6.0 * k, 0, sin(a) * 6.0 * k)
			seg.name = "Root%d_%d" % [i, k]
			y -= strand / parts
	return root

## A cobweb sheet slung across a corner of the ceiling: radial threads and a few sagging rings, in
## a quarter-disc about 1.1 m across.
static func cobwebs() -> Node3D:
	var root := Node3D.new()
	root.name = "Cobwebs"
	var verts := PackedVector3Array()
	var spokes := 6
	var rings := 4
	var radius := 1.1
	for s in spokes + 1:
		var a := PI * 0.5 * float(s) / spokes
		verts.append(Vector3.ZERO)
		verts.append(Vector3(cos(a) * radius, -0.12, sin(a) * radius))
	for r in range(1, rings + 1):
		var rr := radius * float(r) / rings
		var sag := -0.03 - 0.03 * float(r)
		for s in spokes:
			var a0 := PI * 0.5 * float(s) / spokes
			var a1 := PI * 0.5 * float(s + 1) / spokes
			var mid := (a0 + a1) * 0.5
			verts.append(Vector3(cos(a0) * rr, sag * 1.5, sin(a0) * rr))
			verts.append(Vector3(cos(mid) * rr * 0.97, sag * 2.2, sin(mid) * rr * 0.97))   # the thread sags between spokes
			verts.append(Vector3(cos(mid) * rr * 0.97, sag * 2.2, sin(mid) * rr * 0.97))
			verts.append(Vector3(cos(a1) * rr, sag * 1.5, sin(a1) * rr))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.94, 0.98, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var web := MeshInstance3D.new()
	web.mesh = mesh
	web.material_override = mat
	web.name = "Web"
	web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(web)
	var spider := HouseParts._part(root, SphereMesh.new(), Color(0.1, 0.09, 0.1), Vector3(0.6, -0.17, 0.4))   # its owner, small and still
	(spider.mesh as SphereMesh).radius = 0.03
	(spider.mesh as SphereMesh).height = 0.06
	spider.name = "Spider"
	return root

## An old iron lantern hanging from the ceiling on a chain, still burning with a dim warm glow. Its centre
## hangs `length` below the ceiling (4 m by default).
static func hanging_lantern(length := 4.0) -> Node3D:
	var root := Node3D.new()
	root.name = "HangingLantern"
	var iron := HouseParts.IRON
	HouseParts.box(root, Vector3(0.12, 0.04, 0.12), iron, Vector3(0, -0.02, 0)).name = "CeilingPlate"
	var links := maxi(int((length - 0.9) / 0.1), 2)
	for i in links:
		var link := TorusMesh.new()
		link.inner_radius = 0.025
		link.outer_radius = 0.042
		var l := HouseParts._part(root, link, iron.lightened(0.08), Vector3(0, -0.08 - i * 0.1, 0), Vector3(90, 0 if i % 2 == 0 else 90, 0))
		l.scale = Vector3(1.0, 1.0, 1.7)
		l.name = "Link%d" % i
	var body := Node3D.new()
	body.position = Vector3(0, -0.08 - links * 0.1 - 0.2, 0)
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
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.7, 0.35)
	glow.light_energy = 1.1
	glow.omni_range = 5.0
	glow.shadow_enabled = false
	body.add_child(glow)
	return root
