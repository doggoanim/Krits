class_name WellBats
extends Node3D
## A few bats circling in the shaft above the well's entrance — simple black
## silhouettes (a body and two flapping wings, all built in code, no art). Put
## the node at the centre of the circling, around the middle of the opening.
## They wheel at different radii, heights and speeds, and the flap rate varies.

@export var bat_count := 5
@export var radius := Vector2(2.0, 5.0)
@export var height := Vector2(2.0, 7.0)
@export var speed := Vector2(0.5, 1.1)       ## rad/s, sign randomised per bat
@export var flap_rate := Vector2(9.0, 14.0)  ## Hz
@export var bat_size := 0.55
@export var color := Color(0.03, 0.04, 0.06)

var _bats: Array[Dictionary] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in bat_count:
		var root := Node3D.new()
		add_child(root)
		var wing_l := _make_wing(mat, 1.0)
		var wing_r := _make_wing(mat, -1.0)
		root.add_child(wing_l)
		root.add_child(wing_r)
		root.add_child(_make_body(mat))
		_bats.append({
			"root": root, "wl": wing_l, "wr": wing_r,
			"angle": rng.randf() * TAU,
			"radius": rng.randf_range(radius.x, radius.y),
			"height": rng.randf_range(height.x, height.y),
			"speed": rng.randf_range(speed.x, speed.y) * (1.0 if rng.randf() < 0.5 else -1.0),
			"flap": rng.randf_range(flap_rate.x, flap_rate.y),
			"phase": rng.randf() * TAU,
			"bob": rng.randf_range(0.3, 0.9),
		})

func _make_body(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = bat_size * 0.14
	mesh.height = bat_size * 0.36
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A swept-back wing: a flat triangle fan hinged at the body (the node's origin).
func _make_wing(mat: Material, side: float) -> MeshInstance3D:
	var s := bat_size
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0, -0.12 * s), Vector3(side * 0.55 * s, 0.02 * s, -0.25 * s),
		Vector3(side * 0.95 * s, 0.0, 0.1 * s), Vector3(side * 0.5 * s, 0.0, 0.22 * s),
		Vector3(0, 0, 0.14 * s)]
	for tri in [[0, 1, 2], [0, 2, 3], [0, 3, 4]]:
		for idx: int in tri:
			st.add_vertex(pts[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in _bats:
		b["angle"] += float(b["speed"]) * delta
		var a: float = b["angle"]
		var r: float = b["radius"]
		var root := b["root"] as Node3D
		root.position = Vector3(cos(a) * r, float(b["height"]) + sin(t * float(b["bob"]) + float(b["phase"])) * 0.5, sin(a) * r)
		# Face along the circle's tangent, banking slightly into the turn.
		var tangent := Vector3(-sin(a), 0.0, cos(a)) * signf(float(b["speed"]))
		root.rotation = Vector3(0.0, atan2(-tangent.x, -tangent.z), -0.25 * signf(float(b["speed"])))
		var flap := sin(t * float(b["flap"]) + float(b["phase"])) * 0.75
		(b["wl"] as Node3D).rotation.z = flap
		(b["wr"] as Node3D).rotation.z = -flap
