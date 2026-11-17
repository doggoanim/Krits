class_name WaterLife
extends Node3D
## Life in the well's pool: ripples spreading from nowhere in particular, bubbles rising and
## popping, and a few pale fish gliding just under the surface. Built in code from the water
## node (its transform and 20x20 plane size set the pool's outline). Movement is smooth;
## ripple growth, bubbles and the fish's tail are shown in stepped poses (see Choppy).

@export var water_path: NodePath = ^"../Water"
@export var plane_size := Vector2(20.0, 20.0)   ## the water mesh's own size, before scale
@export var inset := 0.85                       ## keep things this fraction inside the edge
@export var fish_count := 3
@export var fish_depth := 0.45
@export var fish_speed := 0.7
@export var ripple_interval := Vector2(1.2, 3.5)
@export var bubble_interval := Vector2(1.5, 4.0)
@export var ripple_color := Color(0.75, 1.0, 1.0, 0.6)
@export var fish_color := Color(0.45, 0.85, 0.9, 0.55)
@export var active_distance := 40.0

class Ring:
	var node: MeshInstance3D
	var age := 0.0
	var life := 1.4
	var size := 1.0

class Bubble:
	var node: MeshInstance3D
	var from := Vector3.ZERO
	var rise := 1.0
	var age := 0.0
	var life := 1.5

class Fish:
	var root: Node3D
	var tail: Node3D
	var angle := 0.0
	var radius := 3.0
	var centre := Vector2.ZERO
	var dir := 1.0

var _water: Node3D
var _ring_tex: Texture2D
var _dot_tex: Texture2D
var _rings: Array[Ring] = []
var _bubbles: Array[Bubble] = []
var _fish: Array[Fish] = []
var _ripple_in := 1.0
var _bubble_in := 1.0
var _last_step := -1
var _step_dt := Choppy.STEP_SECONDS

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_water = get_node_or_null(water_path) as Node3D
	if _water == null:
		set_process(false)
		return
	_ring_tex = SoftCircleTexture.make_ring(64)
	_dot_tex = SoftCircleTexture.make(16)
	for i in fish_count:
		_spawn_fish(i)

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null and player.global_position.distance_to(_water.global_position) > active_distance:
		return
	_ripple_in -= delta
	if _ripple_in <= 0.0:
		_ripple_in = randf_range(ripple_interval.x, ripple_interval.y)
		_spawn_ring(_random_point(), randf_range(0.5, 1.1))
	_bubble_in -= delta
	if _bubble_in <= 0.0:
		_bubble_in = randf_range(bubble_interval.x, bubble_interval.y)
		_spawn_bubble()
	for f in _fish:   # swimming is smooth
		_swim(f, delta)
	var step := Choppy.index()
	if step == _last_step:
		return
	_last_step = step
	_pose_rings()
	_pose_bubbles()
	for f in _fish:
		f.tail.rotation.y = 0.45 * (1.0 if step % 2 == 0 else -1.0)   # a tail flick on every pose

# --- geometry ----------------------------------------------------------------

## Half the pool's size in the water node's own (unscaled) space.
func _half_extent() -> Vector2:
	return plane_size * 0.5 * inset

## A random point on the surface, in world space.
func _random_point() -> Vector3:
	var h := _half_extent()
	return _water.global_transform * Vector3(randf_range(-h.x, h.x), 0.0, randf_range(-h.y, h.y))

func _surface_y() -> float:
	return _water.global_position.y

func _quad(tex: Texture2D, size: Vector2, color: Color, billboard: bool) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = color
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# --- ripples -------------------------------------------------------------------

func _spawn_ring(at: Vector3, size: float) -> void:
	var r := Ring.new()
	r.node = _quad(_ring_tex, Vector2.ONE, ripple_color, false)
	r.size = size
	add_child(r.node)
	r.node.global_position = Vector3(at.x, _surface_y() + 0.03, at.z)
	r.node.rotation_degrees.x = -90.0
	r.node.scale = Vector3.ONE * 0.05
	_rings.append(r)

func _pose_rings() -> void:
	for i in range(_rings.size() - 1, -1, -1):
		var r := _rings[i]
		r.age += _step_dt
		var k := r.age / r.life
		if k >= 1.0:
			r.node.queue_free()
			_rings.remove_at(i)
			continue
		r.node.scale = Vector3.ONE * lerpf(0.05, r.size, 1.0 - pow(1.0 - k, 2.0))
		var mat := (r.node.mesh as QuadMesh).material as StandardMaterial3D
		mat.albedo_color = Color(ripple_color, ripple_color.a * (1.0 - k))

# --- bubbles ---------------------------------------------------------------------

func _spawn_bubble() -> void:
	var b := Bubble.new()
	b.node = _quad(_dot_tex, Vector2.ONE * randf_range(0.05, 0.1), Color(0.85, 1.0, 1.0, 0.7), true)
	b.rise = randf_range(0.8, 1.6)
	b.life = randf_range(1.0, 1.8)
	var p := _random_point()
	b.from = Vector3(p.x, _surface_y() - b.rise, p.z)
	add_child(b.node)
	b.node.global_position = b.from
	_bubbles.append(b)

func _pose_bubbles() -> void:
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b.age += _step_dt
		var k := b.age / b.life
		if k >= 1.0:
			_spawn_ring(Vector3(b.from.x, 0.0, b.from.z), 0.35)   # it pops: a small ripple
			b.node.queue_free()
			_bubbles.remove_at(i)
			continue
		var wobble := sin(b.age * 7.0) * 0.03
		b.node.global_position = b.from + Vector3(wobble, b.rise * k, 0.0)

# --- fish -------------------------------------------------------------------------

func _spawn_fish(index: int) -> void:
	var f := Fish.new()
	f.root = Node3D.new()
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = fish_color
	sphere.material = mat
	body.mesh = sphere
	body.scale = Vector3(1.0, 0.7, 2.6)   # long axis along Z: fish face -Z
	f.root.add_child(body)
	f.tail = Node3D.new()
	f.tail.position = Vector3(0.0, 0.0, 0.3)
	var fin := MeshInstance3D.new()
	var fin_mesh := PrismMesh.new()
	fin_mesh.size = Vector3(0.14, 0.02, 0.18)
	fin_mesh.material = mat
	fin.mesh = fin_mesh
	fin.rotation_degrees.x = 90.0
	fin.position = Vector3(0.0, 0.0, 0.1)
	f.tail.add_child(fin)
	f.root.add_child(f.tail)
	add_child(f.root)
	var h := _half_extent()
	f.centre = Vector2(randf_range(-0.3, 0.3) * h.x, randf_range(-0.3, 0.3) * h.y)
	f.radius = randf_range(0.25, 0.55) * minf(h.x, h.y)
	f.angle = randf() * TAU
	f.dir = 1.0 if index % 2 == 0 else -1.0
	_fish.append(f)

func _swim(f: Fish, delta: float) -> void:
	f.angle += f.dir * fish_speed / f.radius * delta
	var local := Vector3(f.centre.x + cos(f.angle) * f.radius, -fish_depth, f.centre.y + sin(f.angle) * f.radius * 0.8)
	var pos := _water.global_transform * local   # local to the (scaled) water node
	var tangent := Vector3(-sin(f.angle), 0.0, cos(f.angle) * 0.8) * f.dir
	f.root.global_position = pos
	if tangent.length() > 0.001:
		f.root.global_basis = Basis.looking_at(_water.global_transform.basis * tangent, Vector3.UP)
