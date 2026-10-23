class_name WorldTree
extends Node3D
## A single world tree. Attached directly to each hand-placed tree position
## in hometown.tscn (keeping the level author's chosen spot) — everything
## else is picked here at _ready(): which trunk/leaves mesh, how tall, which
## way it's facing, so a dozen identical placements don't all look identical.
##
## The source meshes (assets/world/trunk_*.glb, leaves_*.glb) are modeled
## much larger than the game's own scale and pivoted at their own vertical
## center rather than their base — TRUNK_RAW_HEIGHT/_MIN_Y and
## LEAVES_RAW_HEIGHT/_MIN_Y (measured once from each file's own bounding box)
## are what let _ready() rescale each one down to TARGET_TRUNK_HEIGHT/
## TARGET_LEAVES_HEIGHT and re-anchor it onto y=0 instead of guessing.

const TRUNK_SCENES := [
	preload("res://assets/world/trunk_1.glb"),
	preload("res://assets/world/trunk_2.glb"),
	preload("res://assets/world/trunk_3.glb"),
	preload("res://assets/world/trunk_4.glb"),
]
const LEAVES_SCENES := [
	preload("res://assets/world/leaves_1.glb"),
	preload("res://assets/world/leaves_2.glb"),
	preload("res://assets/world/leaves_3.glb"),
]

## Each raw mesh's own total height and lowest point along Y, in its own file's
## units — index matches TRUNK_SCENES/LEAVES_SCENES above. Re-measure these
## (e.g. via a glTF bounding-box check) if the source files are ever replaced.
const TRUNK_RAW_HEIGHT: Array[float] = [9.601, 9.716, 9.559, 10.299]
const TRUNK_RAW_MIN_Y: Array[float] = [-4.624, -4.624, -4.624, -4.624]
const LEAVES_RAW_HEIGHT: Array[float] = [8.871, 12.892, 5.257]
const LEAVES_RAW_MIN_Y: Array[float] = [-3.234, -5.905, -2.129]

const TARGET_TRUNK_HEIGHT := 3.0    ## matches the old placeholder cylinder trunk's height
const TARGET_LEAVES_HEIGHT := 3.2   ## matches the old placeholder cone foliage's height
const SCALE_JITTER := Vector2(0.85, 1.25)   ## per-tree uniform size variety
## Fraction of the (scaled) leaves' own height that sinks down past the
## trunk's top, so the canopy reads as sitting ON the trunk instead of
## floating above it with a visible gap — matches the old placeholder's own
## trunk/foliage overlap (foliage sat ~15% of its height into the trunk top).
const LEAVES_OVERLAP_FRAC := 0.15
const TRUNK_COLLIDER_RADIUS_FRAC := 0.08   ## vs. the old placeholder's 0.25/3.0 ratio

func _ready() -> void:
	var jitter := randf_range(SCALE_JITTER.x, SCALE_JITTER.y)
	rotation.y = randf_range(0.0, TAU)

	var trunk_height := TARGET_TRUNK_HEIGHT * jitter
	var trunk_i := randi() % TRUNK_SCENES.size()
	var trunk_scale := trunk_height / TRUNK_RAW_HEIGHT[trunk_i]
	var trunk := TRUNK_SCENES[trunk_i].instantiate() as Node3D
	add_child(trunk)
	trunk.scale = Vector3.ONE * trunk_scale
	trunk.position.y = -TRUNK_RAW_MIN_Y[trunk_i] * trunk_scale   # lifts its base onto y=0
	_add_trunk_collision(trunk_height)

	var leaves_height := TARGET_LEAVES_HEIGHT * jitter
	var leaves_i := randi() % LEAVES_SCENES.size()
	var leaves_scale := leaves_height / LEAVES_RAW_HEIGHT[leaves_i]
	var leaves := LEAVES_SCENES[leaves_i].instantiate() as Node3D
	add_child(leaves)
	leaves.scale = Vector3.ONE * leaves_scale
	leaves.rotation.y = randf_range(0.0, TAU)   # spun independently of the trunk so
												 # identical trunk+leaves picks still differ
	var leaves_bottom_target := trunk_height - leaves_height * LEAVES_OVERLAP_FRAC
	leaves.position.y = leaves_bottom_target - LEAVES_RAW_MIN_Y[leaves_i] * leaves_scale

## A plain cylinder stand-in for collision rather than a trimesh of the actual
## (irregular, gnarled) trunk mesh — cheap, and a dozen-plus of these around
## town don't need pixel-perfect collision against a tree's own silhouette.
func _add_trunk_collision(trunk_height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.height = trunk_height
	shape.radius = trunk_height * TRUNK_COLLIDER_RADIUS_FRAC
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = trunk_height * 0.5
	body.add_child(cs)
	add_child(body)
