class_name Orb
extends Area3D
## Floating bounce target. Emits `hit` once, then waits to be relocated by the arena.

signal hit(orb: Orb)

var active := true
var _mesh: MeshInstance3D
var _mat := StandardMaterial3D.new()
var _t := randf() * TAU

func _ready() -> void:
	collision_layer = 1 << 4   # layer 5: orb
	collision_mask = 1 << 1    # player
	var s := SphereShape3D.new()
	s.radius = 0.8
	var cs := CollisionShape3D.new()
	cs.shape = s
	add_child(cs)
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sm
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = _mat
	add_child(_mesh)
	_refresh()

func _physics_process(delta: float) -> void:
	_t += delta * 2.0
	_mesh.position.y = sin(_t) * 0.15
	if active:
		for b in get_overlapping_bodies():
			_try(b)

func _try(body: Node3D) -> void:
	if not active or not (body is Player):
		return
	var p := body as Player
	if p.dead or p.is_on_floor():
		return
	active = false
	_refresh()
	hit.emit(self)

func relocate(pos: Vector3) -> void:
	global_position = pos
	active = true
	_refresh()

func _refresh() -> void:
	_mat.albedo_color = Color(0.2, 0.9, 1.0) if active else Color(0.25, 0.3, 0.35, 0.3)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if active else BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.scale = Vector3.ONE if active else Vector3.ONE * 0.5
