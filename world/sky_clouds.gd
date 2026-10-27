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

@export var area_size := Vector2(150.0, 150.0)   ## how wide a patch of sky this covers, centered on this node
@export var height := 35.0                        ## how high above this node's own Y the layer sits
@export var cloud_count := 14
@export var cloud_size := Vector2(18.0, 10.0)
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
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(area_size.x, 4.0, area_size.y) * 0.5
	mat.emission_shape_offset = Vector3(0.0, height, 0.0)   # lifts the whole box up without moving this node itself
	mat.scale_min = 0.7
	mat.scale_max = 1.4
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

	amount = cloud_count
	lifetime = area_size.x / maxf(drift_speed, 0.05)   # ~ time to drift across area_size once
	preprocess = lifetime   # pre-roll so the sky is already full of clouds on load, not empty at first
	randomness = 1.0
	local_coords = false
	draw_pass_1 = quad
	process_material = mat
	emitting = true
	_mat = mat

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
