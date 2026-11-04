class_name CloudShadows
extends Node3D
## Invisible clouds drifting slowly overhead, casting nothing of themselves but
## a moving shadow patch on the terrain below — the sun (DirectionalLight3D)
## needs shadows enabled for this to show up at all (see
## EnvironmentConfig.sun_shadows, on by default).
##
## Each cloud is a small clump of randomly stacked, randomly sized and rotated
## primitive meshes (boxes, cylinders, spheres) set to
## GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: Godot renders them
## into the shadow map but skips them in the normal color pass, so nothing
## floats visibly in the sky — just a lumpy, chunky shadow sliding across the
## ground. The sun's own shadow_blur (EnvironmentConfig.sun_shadow_blur)
## softens the edges.
##
## Usage: add as a single node anywhere in a level — one instance manages
## several clouds drifting together across drift_area and wrapping back
## around once they pass out the far side.

@export var height := 25.0                     ## how high above this node's own Y the clouds drift
@export var drift_area := Vector2(80.0, 80.0)  ## how far clouds travel before wrapping back around
@export var blob_count := 4
@export var blob_size := Vector2(14.0, 10.0)   ## rough footprint of one whole cloud (X, Z)
@export var pieces_per_cloud := Vector2i(5, 9) ## min/max meshes stacked into one cloud
@export var piece_size := Vector2(0.25, 0.55)  ## each piece's footprint as a fraction of the cloud's — min/max
@export var drift_speed := 1.2                 ## world units/sec along +X — same travel direction WindGusts uses
## How far (world units, along the drift's own X travel) from each end of
## drift_area a cloud spends fading — shrinking away just before it wraps back
## around, growing back in just after, so its shadow never pops in or out.
@export var edge_fade_distance := 12.0

var _clouds: Array[Node3D] = []

func _ready() -> void:
	for i in blob_count:
		var cloud := Node3D.new()
		var footprint := blob_size * randf_range(0.7, 1.3)
		var count := randi_range(pieces_per_cloud.x, pieces_per_cloud.y)
		for k in count:
			cloud.add_child(_make_piece(footprint))
		cloud.position = Vector3(
			randf_range(-drift_area.x * 0.5, drift_area.x * 0.5),
			height,
			randf_range(-drift_area.y * 0.5, drift_area.y * 0.5),
		)
		add_child(cloud)
		_clouds.append(cloud)

## One shadow-only primitive somewhere inside the cloud's footprint, at a
## random yaw, with a random height so the pieces genuinely stack.
func _make_piece(footprint: Vector2) -> MeshInstance3D:
	var width := footprint.x * randf_range(piece_size.x, piece_size.y)
	var depth := footprint.y * randf_range(piece_size.x, piece_size.y)
	var thick := minf(width, depth) * randf_range(0.5, 1.2)
	var mesh: Mesh
	match randi() % 3:
		0:
			var box := BoxMesh.new()
			box.size = Vector3(width, thick, depth)
			mesh = box
		1:
			var cyl := CylinderMesh.new()
			cyl.top_radius = width * 0.5
			cyl.bottom_radius = width * 0.5
			cyl.height = thick
			cyl.radial_segments = 8
			mesh = cyl
		_:
			var sphere := SphereMesh.new()
			sphere.radius = width * 0.5
			sphere.height = thick
			sphere.radial_segments = 8
			sphere.rings = 4
			mesh = sphere
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# Scattered across the footprint (denser in the middle), stacked at
	# slightly different heights, each turned a different way.
	mi.position = Vector3(
		randf_range(-0.5, 0.5) * footprint.x * 0.6,
		randf_range(-1.0, 1.0) * thick * 0.5,
		randf_range(-0.5, 0.5) * footprint.y * 0.6)
	mi.rotation = Vector3(0.0, randf() * TAU, 0.0)
	return mi

func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position.x += drift_speed * delta
		if cloud.position.x > drift_area.x * 0.5:
			cloud.position.x -= drift_area.x
		_update_fade(cloud)

## Shadow casting is binary — a mesh either casts or it doesn't, so "fading"
## shrinks the whole cloud toward nothing as it nears drift_area's edge and
## grows it back in on the other side, which the sun's shadow blur turns into
## a shadow melting away rather than a shape popping out of existence.
func _update_fade(cloud: Node3D) -> void:
	var half := drift_area.x * 0.5
	var dist_from_entry := cloud.position.x - (-half)
	var dist_to_exit := half - cloud.position.x
	var fade := clampf(minf(dist_from_entry, dist_to_exit) / edge_fade_distance, 0.0, 1.0)
	cloud.scale = Vector3.ONE * maxf(fade, 0.001)
