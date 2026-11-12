class_name QuestPropVisuals
extends RefCounted
## Placeholder looks for QuestProp, built from primitives with the project's toon
## shader so they sit in the world until real models exist (give the QuestProp a
## `model` and these are skipped). Every build returns a Node3D whose child named
## "Marker" is the little bobbing diamond that says "something to look at here".

const TOON: Shader = preload("res://shading/toon.gdshader")

const ORANGE := Color(0.95, 0.6, 0.25)
const CREAM := Color(1.0, 0.93, 0.8)
const DARK := Color(0.22, 0.14, 0.1)
const PINK := Color(0.95, 0.6, 0.65)
const MARKER_COLOR := Color(1.0, 0.9, 0.4)
const MARKER_NAME := "Marker"

static func build(kind: QuestProp.Kind) -> Node3D:
	var root := Node3D.new()
	match kind:
		QuestProp.Kind.FUR_TUFT:
			_fur_tuft(root)
			_marker(root, 0.7)
		QuestProp.Kind.PAW_PRINTS:
			_paw_prints(root)
			_marker(root, 0.7)
		QuestProp.Kind.BUN:
			_bun(root)
			_marker(root, 0.8)
		QuestProp.Kind.CAT:
			_cat(root)
			_marker(root, 1.3)
	return root

# ------------------------------------------------------------------ helpers

static func _toon(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter(&"albedo_texture", ModelUtil.white_texture())
	m.set_shader_parameter(&"albedo_color", color)
	m.set_shader_parameter(&"rim_strength", 0.0)
	return m

static func _add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3,
		rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _toon(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

static func _cone(radius: float, height: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	return c

static func _disc(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 16
	return c

## The floating "look here" diamond (two cones), unshaded so it always reads.
static func _marker(root: Node3D, height: float) -> void:
	var marker := Node3D.new()
	marker.name = MARKER_NAME
	marker.position.y = height
	root.add_child(marker)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = MARKER_COLOR
	for flip in [1.0, -1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = _cone(0.07, 0.14, 4)
		mi.material_override = mat
		mi.position.y = 0.07 * flip
		mi.rotation_degrees.x = 0.0 if flip > 0.0 else 180.0
		marker.add_child(mi)

# -------------------------------------------------------------------- props

## A few tufts of orange fur snagged on the ground.
static func _fur_tuft(root: Node3D) -> void:
	for i in 4:
		var a := TAU * float(i) / 4.0
		_add(root, _sphere(0.08), ORANGE, Vector3(cos(a) * 0.1, 0.05, sin(a) * 0.1),
				Vector3(0.0, rad_to_deg(a), 0.0), Vector3(1.6, 0.5, 0.7))
	_add(root, _sphere(0.07), CREAM, Vector3(0.0, 0.07, 0.0), Vector3.ZERO, Vector3(1.4, 0.6, 0.8))

## Three muddy paw prints trailing off.
static func _paw_prints(root: Node3D) -> void:
	for p in 3:
		var base := Vector3(-0.4 + p * 0.4, 0.015, (p % 2) * 0.18 - 0.09)
		_add(root, _disc(0.1, 0.03), DARK, base, Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
		for t in 4:
			var ta := deg_to_rad(-55.0 + t * 37.0)
			_add(root, _disc(0.04, 0.03), DARK, base + Vector3(sin(ta) * 0.14, 0.0, -cos(ta) * 0.15))

## A jelly bun on a plate with a bite out of it.
static func _bun(root: Node3D) -> void:
	_add(root, _disc(0.28, 0.03), Color(0.95, 0.95, 0.98), Vector3(0.0, 0.015, 0.0))
	_add(root, _sphere(0.2), Color(0.9, 0.68, 0.35), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
	_add(root, _sphere(0.07), Color(0.85, 0.2, 0.35), Vector3(0.0, 0.2, 0.0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
	_add(root, _sphere(0.07), Color(0.95, 0.95, 0.98), Vector3(0.17, 0.12, 0.08), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))   # the bite

## Biscuit: a round orange tabby, sitting, facing -Z.
static func _cat(root: Node3D) -> void:
	_add(root, _sphere(0.3), ORANGE, Vector3(0.0, 0.27, 0.0), Vector3.ZERO, Vector3(1.0, 0.9, 1.05))
	_add(root, _sphere(0.2), CREAM, Vector3(0.0, 0.25, -0.17), Vector3.ZERO, Vector3(0.85, 0.9, 0.5))   # chest
	_add(root, _sphere(0.21), ORANGE, Vector3(0.0, 0.62, -0.1))                                          # head
	for side in [-1.0, 1.0]:
		_add(root, _cone(0.075, 0.15, 4), ORANGE, Vector3(0.11 * side, 0.82, -0.1), Vector3(0.0, 0.0, -14.0 * side))
		_add(root, _sphere(0.03), DARK, Vector3(0.08 * side, 0.65, -0.28))                                 # eyes
	_add(root, _sphere(0.025), PINK, Vector3(0.0, 0.6, -0.3))                                              # nose
	for s in 3:
		_add(root, _disc(0.015, 0.2), DARK, Vector3(0.0, 0.5 + s * 0.04, 0.12 + s * 0.04),
				Vector3(90.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.0))   # back stripes
	var tail := CapsuleMesh.new()
	tail.radius = 0.05
	tail.height = 0.5
	_add(root, tail, ORANGE, Vector3(0.22, 0.3, 0.28), Vector3(-30.0, 0.0, 35.0))
