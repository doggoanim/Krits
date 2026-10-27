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
## Shape variety comes from a small procedural sprite sheet (see
## _make_cloud_atlas): each of its SHAPE_GRID*SHAPE_GRID frames is itself 2-4
## overlapping soft circles baked together, so a single frame already reads
## as a little stacked cluster rather than one perfectly round blob — no
## real per-particle clustering needed. Every particle picks a random frame
## (and a random rotation) at spawn, so the field doesn't read as the same
## shape copy-pasted across the sky.

@export var area_size := Vector2(150.0, 150.0)   ## how wide a patch of sky this covers, centered on this node
@export var height := 35.0                        ## how high above this node's own Y the layer sits
@export var cloud_count := 14
@export var cloud_size := Vector2(18.0, 10.0)
@export var cloud_color := Color(1.0, 1.0, 1.0, 0.85)
@export var drift_speed := 0.6          ## world units/sec along +X — same travel direction WindGusts uses
@export var react_to_gusts := true      ## clouds visibly speed up while a gust is sweeping through

const SHAPE_GRID := 2       ## 2x2 = 4 distinct cloud-shape frames baked into the atlas
const ATLAS_SIZE := 256     ## total atlas pixels per side (ATLAS_SIZE / SHAPE_GRID per frame)

static var _cloud_atlas: ImageTexture   ## shared across every SkyClouds instance — built once

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
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(area_size.x, 4.0, area_size.y) * 0.5
	mat.emission_shape_offset = Vector3(0.0, height, 0.0)   # lifts the whole box up without moving this node itself
	mat.scale_min = 0.7
	mat.scale_max = 1.4
	mat.color_ramp = _make_fade_ramp(cloud_color)
	# Each particle freezes on one random frame of the shape atlas (anim_speed
	# 0, anim_offset randomized) instead of animating through it — the
	# standard Godot trick for giving particles a random static sprite
	# variant from a frame atlas rather than every particle using frame 0.
	mat.anim_speed_min = 0.0
	mat.anim_speed_max = 0.0
	mat.anim_offset_min = 0.0
	mat.anim_offset_max = 1.0
	mat.angle_min = -180.0   # random initial billboard-plane rotation, so repeated frames don't
	mat.angle_max = 180.0    # all land facing the exact same way either

	if _cloud_atlas == null:
		_cloud_atlas = _make_cloud_atlas()

	var quad := QuadMesh.new()
	quad.size = cloud_size
	var surf := StandardMaterial3D.new()
	surf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	surf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf.vertex_color_use_as_albedo = true
	surf.albedo_texture = _cloud_atlas
	surf.particles_anim_h_frames = SHAPE_GRID
	surf.particles_anim_v_frames = SHAPE_GRID
	surf.particles_anim_loop = false
	quad.material = surf

	amount = cloud_count
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
	var margin: float = maxf(cloud_size.x, cloud_size.y) * 1.5
	visibility_aabb = AABB(
		Vector3(-area_size.x * 0.5 - margin, height - margin, -area_size.y * 0.5 - margin),
		Vector3(area_size.x + margin * 2.0, margin * 2.0, area_size.y + margin * 2.0)
	)

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

## Bakes a SHAPE_GRID x SHAPE_GRID sprite sheet where each frame is 2-4
## overlapping soft circles merged by taking the brightest one at each pixel
## (not summed, so overlaps don't blow out past full white) — a cheap way to
## get a lumpy, "stacked cluster" silhouette per frame without needing
## several real mesh instances per cloud. Built once and cached in
## _cloud_atlas; every SkyClouds instance shares it.
static func _make_cloud_atlas() -> ImageTexture:
	var img := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	var cell := ATLAS_SIZE / SHAPE_GRID
	var rng := RandomNumberGenerator.new()
	rng.seed = 1   # fixed — a stable-looking atlas baked the same way every run, not reshuffled each launch

	for frame_y in SHAPE_GRID:
		for frame_x in SHAPE_GRID:
			var lobes: Array[Vector3] = []   # x, y (cell-local pixels), radius
			for i in rng.randi_range(2, 4):
				lobes.append(Vector3(
					cell * 0.5 + rng.randf_range(-cell * 0.22, cell * 0.22),
					cell * 0.5 + rng.randf_range(-cell * 0.15, cell * 0.15),
					cell * rng.randf_range(0.22, 0.32),
				))
			for py in cell:
				for px in cell:
					var alpha := 0.0
					for lobe in lobes:
						var dist := Vector2(px, py).distance_to(Vector2(lobe.x, lobe.y))
						alpha = maxf(alpha, clampf(1.0 - dist / lobe.z, 0.0, 1.0))
					img.set_pixel(frame_x * cell + px, frame_y * cell + py, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)
