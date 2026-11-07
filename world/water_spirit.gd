@tool
class_name WaterSpirit
extends Node3D
## A little group of water spirits: three cheerful droplets with dot eyes that
## orbit and bob around a shared centre, always turning their faces to the
## camera, trailing tiny drops upward. Everything is built in code in _init()
## (so the meshes exist the moment the scene is instantiated, which lets
## ModelUtil.fit_height size it when it is held up as an item) and the scene
## (world/water_spirit.tscn) is just this script on a Node3D.
##
## Used in the well where the spirits sleep, and as the model ItemGet holds over
## the player's head when they are collected (ItemLibrary.water_spirits()).

const SPIRIT_SHADER := preload("res://world/water_spirit.gdshader")
const WISP_COUNT := 3
const BODY_SIZE := 0.45        ## droplet diameter (m)
const ORBIT_RADIUS := 0.32
const ORBIT_SPEED := 0.9       ## rad/s
const BOB_HEIGHT := 0.08
const EYE_COLOR := Color(0.04, 0.08, 0.18)

## Per-wisp body colours (deep, shallow): slight variations so they don't look cloned.
const TINTS := [
	[Color(0.16, 0.5, 0.92), Color(0.62, 0.93, 1.0)],
	[Color(0.2, 0.62, 0.95), Color(0.7, 0.97, 1.0)],
	[Color(0.12, 0.42, 0.85), Color(0.55, 0.88, 1.0)],
]

var _pivots: Array[Node3D] = []
var _bodies: Array[MeshInstance3D] = []
var _t := 0.0

func _init() -> void:
	for i in WISP_COUNT:
		var pivot := Node3D.new()
		pivot.name = "Wisp%d" % i
		add_child(pivot)
		_pivots.append(pivot)
		var body := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 24
		sphere.rings = 14
		body.mesh = sphere
		body.scale = Vector3.ONE * BODY_SIZE
		var mat := ShaderMaterial.new()
		mat.shader = SPIRIT_SHADER
		mat.set_shader_parameter(&"deep_color", TINTS[i % TINTS.size()][0])
		mat.set_shader_parameter(&"shallow_color", TINTS[i % TINTS.size()][1])
		body.material_override = mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(body)
		_bodies.append(body)
		for side in [-1.0, 1.0]:
			pivot.add_child(_make_eye(side))
	add_child(_make_drops())
	_place(0.0)

func _process(delta: float) -> void:
	_t += delta
	_place(_t)

## Positions every wisp on its orbit and turns it to look at the camera.
func _place(t: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	for i in _pivots.size():
		var pivot := _pivots[i]
		var a := t * ORBIT_SPEED + TAU * float(i) / WISP_COUNT
		pivot.position = Vector3(cos(a) * ORBIT_RADIUS, sin(t * 1.7 + i * 2.1) * BOB_HEIGHT, sin(a) * ORBIT_RADIUS)
		if cam != null:
			var to_cam := cam.global_position - pivot.global_position
			pivot.global_rotation.y = atan2(to_cam.x, to_cam.z)   # eyes sit on +Z
		# A gentle squash and stretch, out of step per wisp.
		var s := sin(t * 3.2 + i * 1.9) * 0.05
		_bodies[i].scale = Vector3(1.0 - s, 1.0 + s, 1.0 - s) * BODY_SIZE

func _make_eye(side: float) -> MeshInstance3D:
	var eye := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	eye.mesh = mesh
	eye.position = Vector3(side * 0.08, 0.02, BODY_SIZE * 0.5 - 0.02)
	eye.scale = Vector3(1.0, 1.5, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = EYE_COLOR
	eye.material_override = mat
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return eye

## Tiny pale drops that float up from the group and shrink away.
func _make_drops() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Drops"
	p.amount = 14
	p.lifetime = 1.8
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = ORBIT_RADIUS
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.4
	p.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.96, 1.0)
	mesh.material = mat
	p.mesh = mesh
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
