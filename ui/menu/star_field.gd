class_name StarField
extends MultiMeshInstance3D
## A scatter of tiny white dots for the menu's pitch-black "space" — one
## MultiMesh draw call, positions rolled once in _ready(). Lives on a node
## placed behind whatever's in front of the camera (see menu_stage.tscn), so
## every dot reads as a distant star, and slowly rotates so the field drifts
## past with a little parallax instead of sitting dead still.
##
## The dots' look (unshaded white) comes from this node's material_override
## in the scene; this script only owns where they go.

@export var count := 450
## Half-size of the box the stars are scattered in, around this node's own
## origin — so moving/rotating the node moves the whole field with it.
@export var extent := Vector3(32.0, 18.0, 9.0)
## Smallest and largest dot diameter in world units. Most read as a few
## pixels at menu distance; the spread is what stops it looking like a grid.
@export var size_range := Vector2(0.02, 0.06)
## Radians per second the whole field turns around Y. Keep it tiny.
@export var drift_speed := 0.015
## 0 rolls a different sky every launch; any other number is a fixed one.
@export var seed_value := 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var dot := SphereMesh.new()
	dot.radius = 0.5
	dot.height = 1.0
	dot.radial_segments = 8
	dot.rings = 4

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot
	mm.instance_count = count
	for i in count:
		var pos := Vector3(
			rng.randf_range(-extent.x, extent.x),
			rng.randf_range(-extent.y, extent.y),
			rng.randf_range(-extent.z, extent.z))
		var s := rng.randf_range(size_range.x, size_range.y)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), pos))
	multimesh = mm

func _process(delta: float) -> void:
	rotate_y(drift_speed * delta)
