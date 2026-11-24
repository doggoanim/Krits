@tool
class_name CritterVisuals
extends RefCounted
## Small low-poly animals for Pettable: a sitting tabby cat, a hen, a bluebird on a stump and a
## koi on a lily pad. Each builder returns a Node3D standing on y = 0, facing local +Z, whose named
## pivots (Body, Head, Tail, WingL, WingR) animate() moves. Built from spheres, cones and
## boxes with the game's toon material (HouseParts.toon), same as every other prop.

const EYE := Color(0.07, 0.06, 0.08)
const SHINE := Color(1, 1, 1)
const PINK := Color(0.95, 0.6, 0.65)
const BEAK := Color(0.98, 0.72, 0.2)

static func build(species: StringName) -> Node3D:
	match species:
		&"hen": return _hen()
		&"bird": return _bird()
		&"koi": return _koi()
		_: return _cat()

# ----------------------------------------------------------------------- cat

static func _cat() -> Node3D:
	var root := Node3D.new()
	var fur := Color(0.92, 0.56, 0.24)
	var stripe := Color(0.66, 0.34, 0.14)
	var cream := Color(0.99, 0.93, 0.8)
	var body := _pivot(root, "Body", Vector3.ZERO)
	# sitting: two haunches, an upright torso, a pale chest
	for x in [-1.0, 1.0]:
		_ball(body, 0.13, fur, Vector3(x * 0.1, 0.13, -0.06), Vector3(0.9, 1.0, 1.15))
	_ball(body, 0.16, fur, Vector3(0, 0.23, 0.0), Vector3(0.95, 1.3, 0.95))
	_ball(body, 0.1, cream, Vector3(0, 0.22, 0.095), Vector3(0.85, 1.25, 0.6))
	for i in 3:   # tabby stripes on the back, wrapped over the shoulders
		_box(body, Vector3(0.2 - i * 0.02, 0.018, 0.02), stripe, Vector3(0, 0.3 - i * 0.045, -0.115 + i * 0.008), Vector3(-12, 0, 0))
	for x in [-1.0, 1.0]:   # front legs and white paws
		_cyl(body, 0.034, 0.17, fur, Vector3(x * 0.062, 0.1, 0.13))
		_ball(body, 0.042, cream, Vector3(x * 0.062, 0.025, 0.155), Vector3(1.0, 0.65, 1.35))
	# tail curled round the front, ringed
	var tail := _pivot(body, "Tail", Vector3(0.06, 0.05, -0.17))
	var path := [Vector3(0.07, 0.0, -0.04), Vector3(0.15, 0.0, 0.03), Vector3(0.2, 0.005, 0.12), Vector3(0.2, 0.015, 0.22), Vector3(0.16, 0.03, 0.29)]
	for i in path.size():
		_ball(tail, 0.042 - i * 0.002, stripe if i % 2 == 1 else fur, path[i])
	_ball(tail, 0.036, cream, Vector3(0.12, 0.045, 0.34))
	# head
	var head := _pivot(body, "Head", Vector3(0, 0.45, 0.04))
	_ball(head, 0.125, fur, Vector3.ZERO, Vector3(1.18, 0.96, 1.0))
	for x in [-1.0, 1.0]:
		_ball(head, 0.06, cream, Vector3(x * 0.085, -0.03, 0.05), Vector3(1, 0.85, 0.9))   # cheeks
		var ear := _mesh(head, _cone(0.0, 0.058, 0.115, 4), fur, Vector3(x * 0.082, 0.125, -0.005))
		ear.rotation_degrees = Vector3(-8, 45, x * -16)
		var inner := _mesh(head, _cone(0.0, 0.034, 0.07, 4), PINK, Vector3(x * 0.082, 0.115, 0.012))
		inner.rotation_degrees = Vector3(-8, 45, x * -16)
		_ball(head, 0.024, EYE, Vector3(x * 0.052, 0.018, 0.108), Vector3(0.9, 1.3, 0.55))
		_ball(head, 0.008, SHINE, Vector3(x * 0.048, 0.03, 0.12))
		for k in [-1.0, 1.0]:   # whiskers
			_box(head, Vector3(0.1, 0.004, 0.004), cream.darkened(0.05), Vector3(x * 0.1, -0.035 + k * 0.014, 0.1), Vector3(0, x * -12, k * 8))
	_ball(head, 0.04, cream, Vector3(0, -0.04, 0.095), Vector3(1.1, 0.8, 0.8))   # muzzle
	_ball(head, 0.016, PINK.darkened(0.1), Vector3(0, -0.018, 0.122), Vector3(1.2, 0.8, 0.8))   # nose
	for i in 3:   # forehead stripes
		_box(head, Vector3(0.012, 0.045, 0.012), stripe, Vector3((i - 1) * 0.03, 0.085, 0.085), Vector3(-30, 0, (i - 1) * -12))
	return root

# ----------------------------------------------------------------------- hen

static func _hen() -> Node3D:
	var root := Node3D.new()
	var white := Color(0.97, 0.94, 0.88)
	var warm := Color(0.9, 0.82, 0.68)
	var red := Color(0.86, 0.22, 0.2)
	var leg := Color(0.95, 0.68, 0.2)
	var body := _pivot(root, "Body", Vector3.ZERO)
	_ball(body, 0.2, white, Vector3(0, 0.3, -0.01), Vector3(0.95, 1.0, 1.2))
	_ball(body, 0.13, white.lightened(0.03), Vector3(0, 0.32, 0.15), Vector3(1.0, 1.1, 0.85))   # puffed breast
	for x in [-1.0, 1.0]:
		var wing := _pivot(body, "WingL" if x < 0.0 else "WingR", Vector3(x * 0.155, 0.34, -0.02))
		_ball(wing, 0.11, warm, Vector3(x * 0.012, -0.05, -0.02), Vector3(0.28, 1.0, 1.35))
		_ball(wing, 0.07, warm.darkened(0.12), Vector3(x * 0.02, -0.08, -0.09), Vector3(0.3, 0.9, 1.3))
		wing.rotation_degrees.z = x * -6.0
	var tail := _pivot(body, "Tail", Vector3(0, 0.36, -0.2))
	for i in 3:
		var f := _ball(tail, 0.1, white.darkened(0.04 * i) if i != 1 else warm, Vector3((i - 1) * 0.045, 0.05, -0.05), Vector3(0.28, 1.0, 0.7))
		f.rotation_degrees = Vector3(-34, 0, (i - 1) * -26)
	for x in [-1.0, 1.0]:   # legs and three-toed feet
		_cyl(body, 0.013, 0.13, leg, Vector3(x * 0.07, 0.065, 0.0))
		for t in 3:
			var toe := _box(body, Vector3(0.012, 0.01, 0.055), leg, Vector3(x * 0.07 + (t - 1) * 0.022, 0.006, 0.03), Vector3(0, (t - 1) * 24.0, 0))
			toe.name = "Toe"
	var head := _pivot(body, "Head", Vector3(0, 0.5, 0.18))
	_ball(head, 0.1, white, Vector3(0, -0.06, -0.025), Vector3(0.8, 1.2, 0.8))   # neck
	_ball(head, 0.078, white, Vector3.ZERO, Vector3(0.95, 1.0, 1.05))
	var beak := _mesh(head, _cone(0.0, 0.03, 0.07, 6), BEAK, Vector3(0, -0.012, 0.09))
	beak.rotation_degrees.x = 90.0
	for i in 3:   # comb
		_ball(head, 0.026 - i * 0.003, red, Vector3(0, 0.085 - i * 0.008, 0.035 - i * 0.03), Vector3(0.55, 1.0, 1.0))
	_ball(head, 0.022, red, Vector3(0, -0.06, 0.062), Vector3(0.6, 1.4, 0.7))   # wattle
	for x in [-1.0, 1.0]:
		_ball(head, 0.014, EYE, Vector3(x * 0.062, 0.016, 0.04), Vector3(0.6, 1.0, 1.0))
		_ball(head, 0.005, SHINE, Vector3(x * 0.066, 0.022, 0.046))
		_ball(head, 0.022, red.lightened(0.15), Vector3(x * 0.058, -0.03, 0.03), Vector3(0.5, 1.0, 0.8))   # ear patch
	return root

# ---------------------------------------------------------------------- bird

static func _bird() -> Node3D:
	var root := Node3D.new()
	var blue := Color(0.38, 0.6, 0.88)
	var deep := Color(0.2, 0.34, 0.66)
	var cream := Color(0.98, 0.92, 0.78)
	var stump := HouseParts.cylinder(root, 0.15, 0.34, HouseParts.WOOD_DARK, Vector3(0, 0.17, 0))
	stump.name = "Stump"
	HouseParts.cylinder(root, 0.13, 0.02, HouseParts.WOOD_LIGHT, Vector3(0, 0.345, 0))   # cut top
	_ring(root, 0.1, HouseParts.WOOD_DARK.lightened(0.15), Vector3(0, 0.357, 0))
	var body := _pivot(root, "Body", Vector3(0, 0.35, 0))
	_ball(body, 0.088, blue, Vector3(0, 0.1, 0), Vector3(1.0, 1.0, 1.2))
	_ball(body, 0.07, cream, Vector3(0, 0.085, 0.04), Vector3(0.95, 0.95, 0.9))
	for x in [-1.0, 1.0]:
		var wing := _pivot(body, "WingL" if x < 0.0 else "WingR", Vector3(x * 0.075, 0.115, -0.01))
		_ball(wing, 0.06, deep, Vector3(x * 0.005, -0.012, -0.03), Vector3(0.3, 0.9, 1.5))
		wing.rotation_degrees.z = x * -8.0
		_cyl(body, 0.006, 0.05, BEAK.darkened(0.2), Vector3(x * 0.03, 0.02, 0.01))
		_box(body, Vector3(0.02, 0.006, 0.03), BEAK.darkened(0.2), Vector3(x * 0.03, 0.0, 0.02))
	var tail := _pivot(body, "Tail", Vector3(0, 0.1, -0.1))
	var plume := _box(tail, Vector3(0.05, 0.01, 0.13), deep, Vector3(0, -0.02, -0.06), Vector3(14, 0, 0))
	plume.name = "Plume"
	var head := _pivot(body, "Head", Vector3(0, 0.19, 0.045))
	_ball(head, 0.066, blue, Vector3.ZERO, Vector3(1.0, 0.95, 1.0))
	_ball(head, 0.05, deep, Vector3(0, 0.025, -0.012), Vector3(1.0, 0.7, 1.0))   # cap
	_ball(head, 0.04, cream, Vector3(0, -0.02, 0.03), Vector3(1.2, 0.8, 0.9))   # cheeks
	var beak := _mesh(head, _cone(0.0, 0.016, 0.045, 5), BEAK, Vector3(0, -0.005, 0.07))
	beak.rotation_degrees.x = 90.0
	for x in [-1.0, 1.0]:
		_ball(head, 0.013, EYE, Vector3(x * 0.045, 0.012, 0.03), Vector3(0.6, 1.0, 1.0))
		_ball(head, 0.004, SHINE, Vector3(x * 0.049, 0.017, 0.035))
	return root

# ---------------------------------------------------------------------- koi

static func _koi() -> Node3D:
	var root := Node3D.new()
	var white := Color(0.99, 0.96, 0.9)
	var orange := Color(0.98, 0.5, 0.18)
	var ink := Color(0.14, 0.12, 0.16)
	var pad := Color(0.28, 0.62, 0.34)
	# lily pad with a flower for company
	var padm := HouseParts.cylinder(root, 0.26, 0.02, pad, Vector3(0.42, 0.012, 0.22))
	padm.name = "Pad"
	for i in 6:
		var a := TAU * float(i) / 6.0
		var petal := _ball(root, 0.045, Color(1.0, 0.72, 0.8), Vector3(0.42 + cos(a) * 0.045, 0.05, 0.22 + sin(a) * 0.045), Vector3(0.5, 1.2, 1.0))
		petal.rotation.y = -a
	_ball(root, 0.03, Color(1.0, 0.9, 0.4), Vector3(0.42, 0.05, 0.22))
	var body := _pivot(root, "Body", Vector3(-0.1, 0.0, 0.0))
	_ball(body, 0.1, white, Vector3(0, 0.03, 0.0), Vector3(0.8, 0.62, 2.5))   # long body, half sunk in the water
	_ball(body, 0.092, orange, Vector3(0, 0.05, 0.1), Vector3(0.8, 0.45, 1.5))   # head patch
	_ball(body, 0.08, orange, Vector3(0.015, 0.058, -0.1), Vector3(0.85, 0.4, 1.2))
	_ball(body, 0.05, ink, Vector3(-0.025, 0.07, -0.02), Vector3(0.9, 0.35, 1.2))
	for x in [-1.0, 1.0]:
		_ball(body, 0.014, EYE, Vector3(x * 0.062, 0.05, 0.19), Vector3(0.6, 1.0, 1.0))
		_ball(body, 0.005, SHINE, Vector3(x * 0.066, 0.056, 0.195))
		_box(body, Vector3(0.1, 0.012, 0.045), white.darkened(0.04), Vector3(x * 0.11, 0.02, 0.07), Vector3(0, x * -30, x * 18))   # pectoral fins
		_box(body, Vector3(0.008, 0.008, 0.045), white.darkened(0.15), Vector3(x * 0.03, 0.045, 0.255), Vector3(0, x * 25, 0))   # barbels
	_box(body, Vector3(0.012, 0.075, 0.13), orange.lightened(0.1), Vector3(0, 0.1, -0.02), Vector3(-14, 0, 0))   # dorsal fin
	var tail := _pivot(body, "Tail", Vector3(0, 0.035, -0.26))
	for x in [-1.0, 1.0]:
		var fin := _box(tail, Vector3(0.012, 0.012, 0.17), white, Vector3(x * 0.04, 0, -0.08), Vector3(0, x * -26, 0))
		fin.name = "TailFin"
	return root

# ------------------------------------------------------------------- motion

## Idle motion at time `t`. `excite` (0..1) is how happy it is right now (just petted).
static func animate(root: Node3D, species: StringName, t: float, excite: float) -> void:
	var body := root.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var tail := body.get_node_or_null("Tail") as Node3D
	var head := body.get_node_or_null("Head") as Node3D
	var wing_l := body.get_node_or_null("WingL") as Node3D
	var wing_r := body.get_node_or_null("WingR") as Node3D
	match species:
		&"cat":
			body.scale = Vector3(1.0, 1.0 + 0.018 * sin(t * 2.2), 1.0)
			if tail: tail.rotation.y = sin(t * (1.6 + excite * 7.0)) * (0.16 + excite * 0.3)
			if head:
				head.rotation = Vector3(sin(t * 0.5) * 0.04 - excite * 0.2, sin(t * 0.4) * 0.22, sin(t * 0.7) * 0.07 + excite * sin(t * 12.0) * 0.1)
			body.position.y = excite * absf(sin(t * 14.0)) * 0.05
		&"hen":
			var peck := maxf(0.0, sin(t * 1.4)) ** 6.0
			if head: head.rotation.x = peck * 0.7 * (1.0 - excite)
			body.rotation.x = peck * 0.18 * (1.0 - excite)
			if tail: tail.rotation.x = -peck * 0.15 + sin(t * 3.0) * 0.03
			var flap := excite * sin(t * 34.0) * 0.5
			if wing_l: wing_l.rotation.z = 0.1 + flap
			if wing_r: wing_r.rotation.z = -0.1 - flap
			body.position.y = excite * absf(sin(t * 16.0)) * 0.06
		&"bird":
			var hop := excite * absf(sin(t * 18.0)) * 0.07
			body.position.y = 0.35 + hop + maxf(0.0, sin(t * 3.3)) * 0.008
			if head: head.rotation = Vector3(sin(t * 5.0) * 0.1 * excite, sin(t * 0.9) * 0.6, 0)
			if tail: tail.rotation.x = sin(t * 2.6) * 0.12 + excite * sin(t * 22.0) * 0.2
			var flap := excite * (sin(t * 40.0) * 0.4 + 0.2)
			if wing_l: wing_l.rotation.z = 0.14 + flap
			if wing_r: wing_r.rotation.z = -0.14 - flap
		&"koi":
			body.rotation.y = sin(t * 0.8) * 0.28 + excite * sin(t * 9.0) * 0.18
			body.position = Vector3(-0.1 + sin(t * 0.6) * 0.05, excite * 0.1 * absf(sin(t * 8.0)), cos(t * 0.5) * 0.03)
			if tail: tail.rotation.y = sin(t * (3.0 + excite * 9.0)) * (0.35 + excite * 0.25)
			var pad := root.get_node_or_null("Pad") as Node3D
			if pad: pad.rotation.y = sin(t * 0.4) * 0.1

# ------------------------------------------------------------------ helpers

static func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	return n

static func _mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	return PlayProps._mesh(parent, mesh, color, pos)

static func _ball(parent: Node3D, radius: float, color: Color, pos: Vector3, stretch := Vector3.ONE) -> MeshInstance3D:
	return PlayProps._ball(parent, radius, color, pos, stretch)

static func _box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	return HouseParts.box(parent, size, color, pos, rot_deg)

static func _cyl(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	return HouseParts.cylinder(parent, radius, height, color, pos)

static func _cone(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var m := PlayProps._cone(top, bottom, height)
	m.radial_segments = segments
	return m

## A thin flat disc (tree-ring look on a stump top).
static func _ring(parent: Node3D, radius: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = radius * 0.92
	m.outer_radius = radius
	m.rings = 16
	m.ring_segments = 4
	var mi := _mesh(parent, m, color, pos)
	mi.scale.y = 0.2
	return mi
