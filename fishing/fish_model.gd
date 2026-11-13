class_name FishModel
extends RefCounted
## A simple toon fish built from primitives (no model files yet): an oval body,
## a tail, two eyes. 1 unit long, nose pointing along +X, so scale the returned
## node by the fish's length in metres. Used for the fish that leaps out of the
## water (FishingSession) and the one held up (HeldItem).

static func build(color: Color) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	body.mesh = sphere
	body.scale = Vector3(0.82, 0.38, 0.24)
	body.material_override = _toon(color)
	root.add_child(body)

	var tail := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.3
	tail.mesh = cone
	tail.rotation_degrees.z = -90.0   # apex toward the body
	tail.scale = Vector3(1.0, 1.0, 0.3)
	tail.position = Vector3(-0.5, 0.0, 0.0)
	tail.material_override = _toon(color.darkened(0.2))
	root.add_child(tail)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.03
		dot.height = 0.06
		eye.mesh = dot
		eye.position = Vector3(0.27, 0.07, 0.09 * side)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.05, 0.08)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye.material_override = mat
		root.add_child(eye)
	return root

static func _toon(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
