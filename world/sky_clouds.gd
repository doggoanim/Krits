class_name SkyClouds
extends GPUParticles3D
## A layer of big, soft white puffs drifting slowly across the sky — the
## visible counterpart to world/cloud_shadows.gd's invisible shadow-only
## blobs (that file casts the shadows on the ground; this one is purely what
## you SEE overhead, the two aren't currently position-linked). Same bolt-on
## idiom as AmbientMotes/FallingLeaves: drop one of these in a level and it
## drifts on its own, no setup() call needed.
##
## Deliberately simple rather than a true volumetric/chunked multi-mesh
## system — a wide, sparse field of big soft sprites at a fixed altitude,
## looping the same spawn-drift-fade-respawn way AmbientMotes' dust does.
## Good enough to read as "there are clouds up there"; swap for something
## heavier later if the game ever needs clouds the camera can fly through or
## that drive actual weather.
##
## Each cloud is the same soft round sprite AmbientMotes/FallingLeaves
## already use (proven to look fine, unlike an earlier hand-baked lumpy-
## shape attempt here that didn't). "Varied, can-stack" shapes come from
## cluster_lobes: several of these soft circles spawn stacked tightly
## together per cloud, each with its own randomized size, so the overlap
## itself is what reads as one bigger lumpy cluster instead of a single
## perfectly round blob — real overlapping sprites, not a baked texture
## trick.

@export var area_size := Vector2(150.0, 150.0)   ## how wide a patch of sky this covers, centered on this node
@export var height := 35.0                        ## how high above this node's own Y the layer sits
@export var cloud_count := 10                      ## number of CLUSTERS — actual sprite count is this * cluster_lobes
@export var cluster_lobes := 4                      ## soft circles stacked per cluster — higher = lumpier/fluffier
@export var cluster_spread := 6.0                   ## how far a cluster's lobes scatter from its own center
@export var cloud_size := Vector2(16.0, 16.0)
@export var cloud_color := Color(1.0, 1.0, 1.0, 0.85)
@export var drift_speed := 0.6          ## world units/sec along +X — same travel direction WindGusts uses
@export var react_to_gusts := true      ## clouds visibly speed up while a gust is sweeping through

var _mat: ParticleProcessMaterial

func _ready() -> void:
	_build()
	set_process(react_to_gusts)

func _process(_delta: float) -> void:
	var pos := global_position
	var gust := WindGusts.sample(Vector2(pos.x, pos.z), Time.get_ticks_msec() / 1000.0)
	_mat.initial_velocity_min = drift_speed * 0.8 * gust
	_mat.initial_velocity_max = drift_speed * gust

func _build() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.RIGHT
	mat.spread = 5.0   # a narrow cone, not scattering every which way — clouds all drift one direction
	mat.initial_velocity_min = drift_speed * 0.8
	mat.initial_velocity_max = drift_speed
	mat.gravity = Vector3.ZERO
	# Explicit jittered points rather than one big box: every lobe's spawn
	# point is baked close to its own cluster's siblings (see
	# _make_cluster_points), which is what makes several overlapping soft
	# circles actually overlap instead of scattering independently and
	# rarely landing near each other.
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	mat.emission_points = _make_cluster_points()
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	mat.color_ramp = _make_fade_ramp(cloud_color)

	var quad := QuadMesh.new()
	quad.size = cloud_size
	var surf := StandardMaterial3D.new()
	surf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	surf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf.vertex_color_use_as_albedo = true
	surf.albedo_texture = SoftCircleTexture.make(48)
	quad.material = surf

	amount = cloud_count * cluster_lobes
	lifetime = area_size.x / maxf(drift_speed, 0.05)   # ~ time to drift across area_size once
	preprocess = lifetime   # pre-roll so the sky is already full of clouds on load, not empty at first
	randomness = 1.0
	local_coords = false
	draw_pass_1 = quad
	process_material = mat
	emitting = true
	_mat = mat

	# GPUParticles3D auto-computes a visibility bounding box from a short
	# initial sample of particle motion, which badly undershoots how far
	# these actually drift across a wide area_size — once that box falls
	# outside the camera's frustum (easy to trigger just by looking at a
	# certain angle), Godot culls the ENTIRE system even though individual
	# particles are still clearly on screen. Setting this explicitly, sized
	# to the real drift area plus a margin for each cloud's own size, is
	# what actually fixes the "clouds disappear at some angles" symptom.
	var margin: float = maxf(cloud_size.x, cloud_size.y) * 1.5 + cluster_spread
	visibility_aabb = AABB(
		Vector3(-area_size.x * 0.5 - margin, height - margin, -area_size.y * 0.5 - margin),
		Vector3(area_size.x + margin * 2.0, margin * 2.0, area_size.y + margin * 2.0)
	)

## cloud_count cluster centers scattered across area_size at `height`, each
## with cluster_lobes points jittered within cluster_spread of it — see this
## file's header comment for why clustered points (not one big random box)
## is what makes clouds read as lumpy stacked clusters.
func _make_cluster_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in cloud_count:
		var center := Vector3(
			randf_range(-area_size.x * 0.5, area_size.x * 0.5),
			height,
			randf_range(-area_size.y * 0.5, area_size.y * 0.5),
		)
		for j in cluster_lobes:
			points.append(center + Vector3(
				randf_range(-cluster_spread, cluster_spread),
				randf_range(-cluster_spread * 0.3, cluster_spread * 0.3),
				randf_range(-cluster_spread, cluster_spread),
			))
	return points

static func _make_fade_ramp(c: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0),
		c,
		Color(c.r, c.g, c.b, 0.0),
	])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
