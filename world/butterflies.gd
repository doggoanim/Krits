class_name Butterflies
extends Node3D
## A few small butterflies fluttering around a spot — drop one in a level near
## flowers. Each butterfly wanders between random points inside `radius`, bobbing
## as it goes, with two wings that flap. Cheap (a handful of quads moved by
## script), and purely decorative.

@export var butterfly_count := 4
@export var radius := 5.0
@export var height_range := Vector2(0.6, 2.0)   ## flying height above this node's own Y
@export var speed := 1.1
@export var wing_size := 0.16
@export var flap_speed := 16.0
@export var palette: Array[Color] = [
	Color(1.0, 0.82, 0.3), Color(0.95, 0.55, 0.7), Color(0.6, 0.8, 1.0), Color(1.0, 1.0, 0.95),
]

class Flyer:
	var root: Node3D
	var left: Node3D
	var right: Node3D
	var target := Vector3.ZERO
	var phase := 0.0
	var bob_phase := 0.0

var _flyers: Array[Flyer] = []
var _wing_mesh: QuadMesh
var _wing_tex: ImageTexture

func _ready() -> void:
	_wing_tex = _make_wing_texture()
	_wing_mesh = QuadMesh.new()
	_wing_mesh.size = Vector2.ONE * wing_size
	_wing_mesh.center_offset = Vector3(wing_size * 0.5, 0.0, 0.0)   # hinge on the body edge
	for i in butterfly_count:
		_flyers.append(_make_flyer(palette[i % palette.size()]))

func _make_flyer(color: Color) -> Flyer:
	var f := Flyer.new()
	f.root = Node3D.new()
	add_child(f.root)
	f.phase = randf() * TAU
	f.bob_phase = randf() * TAU
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _wing_tex
	mat.albedo_color = color
	f.left = _make_wing(mat, true)
	f.right = _make_wing(mat, false)
	f.root.add_child(f.left)
	f.root.add_child(f.right)
	f.root.position = _random_point()
	f.target = _random_point()
	return f

func _make_wing(mat: Material, is_left: bool) -> Node3D:
	var hinge := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _wing_mesh
	mi.material_override = mat
	mi.rotation.x = -PI * 0.5            # lie flat (the quad faces +Z by default)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hinge.add_child(mi)
	if is_left:
		hinge.scale.x = -1.0               # mirror to the other side of the body
	return hinge

func _random_point() -> Vector3:
	var a := randf() * TAU
	var r := sqrt(randf()) * radius
	return Vector3(cos(a) * r, randf_range(height_range.x, height_range.y), sin(a) * r)

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in _flyers:
		var to := f.target - f.root.position
		if to.length() < 0.4:
			f.target = _random_point()
		else:
			var dir := to.normalized()
			f.root.position += dir * speed * delta
			f.root.position.y += sin(t * 5.0 + f.bob_phase) * 0.6 * delta   # bob
			# face the way it is flying
			f.root.rotation.y = lerp_angle(f.root.rotation.y, atan2(-dir.x, -dir.z), 4.0 * delta)
		var flap := sin(t * flap_speed + f.phase) * 1.0   # -1..1
		f.right.rotation.z = flap * 0.9
		f.left.rotation.z = -flap * 0.9

## A rounded wing shape: a soft ellipse, darker toward the edge.
func _make_wing_texture() -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) / size, (y + 0.5) / size)
			var d := Vector2((p.x - 0.35) / 0.62, (p.y - 0.5) / 0.48).length()
			var a := clampf((1.0 - d) / 0.12, 0.0, 1.0)
			var shade := lerpf(1.0, 0.7, clampf(d, 0.0, 1.0))
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return ImageTexture.create_from_image(img)
