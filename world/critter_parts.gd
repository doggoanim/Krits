@tool
class_name CritterParts
extends RefCounted
## Little animals built from a handful of simple shapes in the project's toon look: a small
## songbird, a chicken and a sitting cat. Each builder returns a Dictionary of the rig's
## named parts ({"root": Node3D, ...}) so a behaviour script (Birds, Chickens, RoofCat) can
## animate them without knowing how they're assembled. Animals face -Z; origin is at the feet.

const BEAK := Color(0.95, 0.7, 0.2)
const EYE := Color(0.08, 0.06, 0.06)
const RED := Color(0.85, 0.15, 0.12)

static func _blob(parent: Node3D, radius: float, stretch: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = HouseParts.toon(color)
	mi.scale = stretch
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _cone(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = HouseParts.toon(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func _eyes(head: Node3D, spread: float, y: float, z: float, size: float) -> void:
	for sx in [-1.0, 1.0]:
		_blob(head, size, Vector3.ONE, EYE, Vector3(sx * spread, y, z))

## A songbird about 12 cm long. Parts: root, body, head, left_wing, right_wing, tail.
static func bird(back: Color, belly: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "Bird"
	var body := _blob(root, 0.07, Vector3(1.0, 0.9, 1.5), back, Vector3(0, 0.08, 0))
	_blob(root, 0.062, Vector3(0.95, 0.7, 1.2), belly, Vector3(0, 0.055, -0.02))   # lighter belly
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.13, -0.09)
	root.add_child(head)
	_blob(head, 0.045, Vector3.ONE, back.lightened(0.05), Vector3.ZERO)
	_cone(head, 0.013, 0.045, BEAK, Vector3(0, -0.005, -0.055), Vector3(-90, 0, 0))
	_eyes(head, 0.032, 0.012, -0.02, 0.009)
	var tail := HouseParts.box(root, Vector3(0.05, 0.01, 0.1), back.darkened(0.2), Vector3(0, 0.085, 0.13), Vector3(-14, 0, 0))
	tail.name = "Tail"
	var wings: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "LeftWing" if sx < 0.0 else "RightWing"
		hinge.position = Vector3(sx * 0.06, 0.11, 0.0)
		root.add_child(hinge)
		HouseParts.box(hinge, Vector3(0.11, 0.008, 0.08), back.darkened(0.12), Vector3(sx * 0.055, 0, 0.01))
		wings.append(hinge)
	return {"root": root, "body": body, "head": head, "left_wing": wings[0], "right_wing": wings[1], "tail": tail}

## A hen about 35 cm tall. Parts: root, body, neck (pivot: pitch it to peck), left_wing, right_wing.
static func chicken(feathers: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "Chicken"
	var body := _blob(root, 0.13, Vector3(0.9, 1.0, 1.3), feathers, Vector3(0, 0.27, 0.02))
	for i in 3:   # tail feathers fanning up and back
		_cone(root, 0.035, 0.2, feathers.darkened(0.12 + 0.05 * i), Vector3((i - 1) * 0.04, 0.4, 0.2), Vector3(-160 + (i - 1) * 8, 0, (i - 1) * 14))
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.34, -0.1)
	root.add_child(neck)
	var head := Node3D.new()
	head.position = Vector3(0, 0.1, -0.05)
	neck.add_child(head)
	_blob(neck, 0.05, Vector3(0.9, 1.4, 0.9), feathers.lightened(0.05), Vector3(0, 0.04, -0.01))
	_blob(head, 0.05, Vector3.ONE, feathers.lightened(0.08), Vector3.ZERO)
	_cone(head, 0.017, 0.055, BEAK, Vector3(0, -0.005, -0.06), Vector3(-90, 0, 0))
	HouseParts.box(head, Vector3(0.012, 0.045, 0.06), RED, Vector3(0, 0.055, -0.005))                  # comb
	_blob(head, 0.014, Vector3(0.8, 1.6, 0.8), RED, Vector3(0, -0.055, -0.045))                          # wattle
	_eyes(head, 0.04, 0.012, -0.025, 0.008)
	for sx in [-1.0, 1.0]:                                                                                # legs
		var leg := HouseParts.cylinder(root, 0.009, 0.16, BEAK.darkened(0.15), Vector3(sx * 0.05, 0.08, 0.02))
		leg.name = "Leg"
		HouseParts.box(root, Vector3(0.05, 0.01, 0.07), BEAK.darkened(0.15), Vector3(sx * 0.05, 0.005, -0.01))
	var wings: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "LeftWing" if sx < 0.0 else "RightWing"
		hinge.position = Vector3(sx * 0.11, 0.3, 0.02)
		root.add_child(hinge)
		HouseParts.box(hinge, Vector3(0.012, 0.11, 0.17), feathers.darkened(0.1), Vector3(sx * 0.005, -0.05, 0.02))
		wings.append(hinge)
	return {"root": root, "body": body, "neck": neck, "left_wing": wings[0], "right_wing": wings[1]}

## A cat sitting upright, about 30 cm tall, facing -Z. Parts: root, body, head (pivot),
## left_ear, right_ear, tail (Array of 5 pivots, base first: rotate each for a swish).
static func cat(fur: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "Cat"
	var body := _blob(root, 0.15, Vector3(0.85, 1.15, 0.95), fur, Vector3(0, 0.17, 0.02))
	_blob(root, 0.1, Vector3(1.25, 0.8, 1.2), fur, Vector3(-0.0, 0.1, 0.08))                           # haunches
	_blob(root, 0.07, Vector3(0.8, 1.2, 0.5), fur.lightened(0.3), Vector3(0, 0.22, -0.12))             # chest
	for sx in [-1.0, 1.0]:
		HouseParts.box(root, Vector3(0.05, 0.16, 0.05), fur, Vector3(sx * 0.055, 0.08, -0.1))           # front legs
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.36, -0.05)
	root.add_child(head)
	_blob(head, 0.095, Vector3(1.1, 0.95, 1.0), fur.lightened(0.04), Vector3.ZERO)
	_blob(head, 0.03, Vector3(1.4, 0.8, 1.0), fur.lightened(0.45), Vector3(0, -0.035, -0.085))         # muzzle
	_blob(head, 0.012, Vector3.ONE, Color(0.9, 0.5, 0.55), Vector3(0, -0.015, -0.112))                  # nose
	for sx in [-1.0, 1.0]:
		_blob(head, 0.011, Vector3(0.7, 1.4, 0.7), Color(0.55, 0.85, 0.3), Vector3(sx * 0.04, 0.015, -0.085))   # eyes
	var ears: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.name = "LeftEar" if sx < 0.0 else "RightEar"
		ear.position = Vector3(sx * 0.06, 0.07, -0.01)
		head.add_child(ear)
		var cone := _cone(ear, 0.035, 0.08, fur.darkened(0.05), Vector3(0, 0.035, 0), Vector3(0, 0, 0))
		cone.rotation_degrees.z = -sx * 12.0
		ears.append(ear)
	var tail: Array[Node3D] = []
	var parent: Node3D = root
	for i in 5:
		var seg := Node3D.new()
		seg.name = "Tail%d" % i
		seg.position = Vector3(0, 0.05, 0.16) if i == 0 else Vector3(0, 0, 0.07)
		parent.add_child(seg)
		_blob(seg, 0.032 - i * 0.003, Vector3(1, 1, 1.5), fur.darkened(0.08 * float(i == 4)), Vector3(0, 0, 0.035))
		tail.append(seg)
		parent = seg
	return {"root": root, "body": body, "head": head, "left_ear": ears[0], "right_ear": ears[1], "tail": tail}
