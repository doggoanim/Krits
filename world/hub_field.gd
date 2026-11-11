class_name HubField
extends Node3D
## The central open field (Hyrule-Field style): a wide plain with one gate per
## region around its rim. Add a region by appending to GATES — the gate, its
## arrival spot and its signpost are all built from that one row.
##
## Row: [id, label, angle in degrees (0 = north, clockwise), target scene
## ("" = sealed for now), spawn id inside the target].

const FIELD_RADIUS := 260.0
const GATE_DISTANCE := 230.0
const GATES: Array = [
	[&"chesburg", "Chesburg", 180.0, "res://world/chesburg.tscn", &"from_field"],
]
const TREES: Array[PackedScene] = [
	preload("res://assets/world/nature/tree_chesburg_1.glb"),
	preload("res://assets/world/nature/tree_chesburg_3.glb"),
	preload("res://assets/world/nature/tree_chesburg_7.glb"),
]
const TREE_COUNT := 90
const GRASS := Color(0.569, 0.733, 0.306)
const STONE := Color(0.62, 0.6, 0.56)

func _ready() -> void:
	_build_ground()
	_scatter_trees()
	for row in GATES:
		_build_gate(row)

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | CameraRig.GROUND_LAYER
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = FIELD_RADIUS
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = -1.0
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = FIELD_RADIUS
	mesh.bottom_radius = FIELD_RADIUS
	mesh.height = 2.0
	mi.mesh = mesh
	mi.position.y = -1.0
	mi.material_override = _flat(GRASS)
	body.add_child(mi)
	add_child(body)

## Trees stay out of the centre and the gate approaches so the paths read clearly.
func _scatter_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	while placed < TREE_COUNT:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (FIELD_RADIUS - 12.0)
		var pos := Vector3(sin(a) * r, 0.0, -cos(a) * r)
		if r < 30.0 or _near_gate_path(pos):
			continue
		var tree := TREES[rng.randi() % TREES.size()].instantiate() as Node3D
		tree.position = pos
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)
		placed += 1

func _near_gate_path(pos: Vector3) -> bool:
	for row in GATES:
		var dir := _dir(row[2])
		var along := pos.dot(dir)
		if along > 0.0 and (pos - dir * along).length() < 14.0:
			return true
	return false

func _build_gate(row: Array) -> void:
	var dir := _dir(row[2])
	var root := Node3D.new()
	root.name = "Gate_" + String(row[0])
	root.position = dir * GATE_DISTANCE
	root.rotation.y = atan2(-dir.x, -dir.z)   # faces the field's centre
	add_child(root)

	var gate := RegionGate.new()
	gate.target_level = row[3]
	gate.target_spawn_id = row[4]
	gate.blocked_text = "%s isn't open yet." % row[1]
	root.add_child(gate)

	for side in [-1.0, 1.0]:   # two pillars and a lintel
		root.add_child(_block(Vector3(side * 3.4, 3.0, 0), Vector3(1.2, 6.0, 1.2)))
	root.add_child(_block(Vector3(0, 6.3, 0), Vector3(8.0, 1.0, 1.4)))

	var sign_label := Label3D.new()
	sign_label.text = row[1]
	sign_label.font_size = 96
	sign_label.outline_size = 24
	sign_label.pixel_size = 0.012
	sign_label.position = Vector3(0, 8.2, 0)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(sign_label)

	# Where the player lands when they come back from that region.
	var arrive := DoorSpawn.new()
	arrive.spawn_id = StringName("from_" + String(row[0]))
	arrive.position = Vector3(0, 0.2, 5.0)   # inside the field, in front of the gate
	root.add_child(arrive)

func _block(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _flat(STONE)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	return body

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

static func _dir(deg: float) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(sin(a), 0.0, -cos(a))
