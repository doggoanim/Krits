class_name OrbLinks
extends Node3D
## Glowing links between the Bow's arrow orbs, in the arrows' own color: each
## arrow orb is tied to its nearest arrow neighbour — the same chain the
## bounce nudges you along (see Arena._handle_bow_hit). Drawn as thin glowing
## rods from a small pool that follows the orbs every frame, so links track
## orbs as they bob, drop in and relocate. Child of the Arena.

const LINK_RADIUS := 0.05
const MIN_LENGTH := 0.2   ## orbs closer than this (stacked) get no link

var arena: Arena
var kind := Orb.Kind.ARROW

var _pool: Array[MeshInstance3D] = []
var _material: StandardMaterial3D

func _ready() -> void:
	var color: Color = Orb.KIND_COLORS[kind][0]
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(color, 0.75)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _process(_delta: float) -> void:
	if arena == null:
		return
	var linked := _pairs()
	while _pool.size() < linked.size():
		_pool.append(_make_rod())
	for i in _pool.size():
		var rod := _pool[i]
		rod.visible = i < linked.size()
		if rod.visible:
			_place(rod, linked[i][0], linked[i][1])

## Each live orb of `kind` paired with its nearest neighbour; a pair that two
## orbs both pick is only listed once.
func _pairs() -> Array:
	var live: Array[Orb] = []
	for o in arena.orbs:
		if is_instance_valid(o) and o.active and o.kind == kind and not o.has_meta(&"stacked"):
			live.append(o)
	var seen := {}
	var out := []
	for a in live:
		var best: Orb = null
		var best_d := INF
		for b in live:
			if b == a:
				continue
			var d := a.global_position.distance_squared_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
		if best == null:
			continue
		var key := [a.get_instance_id(), best.get_instance_id()]
		key.sort()
		if seen.has(key):
			continue
		seen[key] = true
		out.append([a.global_position, best.global_position])
	return out

func _make_rod() -> MeshInstance3D:
	var rod := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = LINK_RADIUS
	mesh.bottom_radius = LINK_RADIUS
	mesh.height = 1.0   # stretched to length in _place()
	mesh.radial_segments = 6
	mesh.rings = 1
	rod.mesh = mesh
	rod.material_override = _material
	rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rod)
	return rod

func _place(rod: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var length := delta.length()
	if length < MIN_LENGTH:
		rod.visible = false
		return
	var dir := delta / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var y := dir
	var x := up.cross(y).normalized()
	var z := x.cross(y).normalized()
	rod.global_transform = Transform3D(Basis(x, y * length, z), (from + to) * 0.5)
