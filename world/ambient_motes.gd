class_name AmbientMotes
extends GPUParticles3D
## A slow-drifting field of small glowing dots, for decorating an outdoor
## space — dust hanging in a sunbeam by default, or glowing fireflies if you
## raise glow_energy and pick a warmer/greener color. Both looks are the same
## underlying effect (a soft round sprite on a lazy random walk inside a box
## region, each one fading in and out over its own long lifetime, which is
## what reads as drifting/twinkling rather than two different systems), so
## one script covers both — see glow_energy's doc below for how to switch.
##
## Usage: add as a plain child node anywhere in a level — an outdoor
## clearing, under a tree canopy, a firefly pocket near the water, whatever
## (see world/hometown.tscn for worked examples). `area_size` is the box
## region particles drift around inside, centered on this node; scale it to
## the space being decorated. Runs entirely on its own once added, no
## setup() call needed — unlike systems that must stay wired to the player
## or camera (OutlineSystem, say), this one doesn't care where either is.

@export var area_size := Vector3(8.0, 4.0, 8.0)
@export var mote_count := 40
@export var color := Color(1.0, 0.95, 0.8, 0.5)   ## warm dust-mote default
@export var glow_energy := 0.0                     ## 0 = unshaded dust; >0 self-lit, firefly-style
@export var mote_size := 0.05
@export var drift_speed := 0.15                    ## both initial velocity and turbulence strength
@export var react_to_gusts := true                  ## stir harder when a WindGusts gust sweeps through

var _mat: ParticleProcessMaterial

func _ready() -> void:
	_build()
	set_process(react_to_gusts)

func _process(_delta: float) -> void:
	var pos := global_position
	var gust := WindGusts.sample(Vector2(pos.x, pos.z), Time.get_ticks_msec() / 1000.0)
	_mat.turbulence_noise_strength = drift_speed * gust

func _build() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 180.0   # every direction, not a cone — motes drift every which way
	mat.initial_velocity_min = drift_speed * 0.5
	mat.initial_velocity_max = drift_speed
	mat.gravity = Vector3.ZERO   # motes hang/drift, they don't fall like smoke or debris
	mat.damping_min = 0.1
	mat.damping_max = 0.3
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = area_size * 0.5
	mat.scale_min = 0.7
	mat.scale_max = 1.3
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = drift_speed
	mat.turbulence_noise_scale = 2.0
	# Fade each mote in, hold, then fade out over its own lifetime instead of
	# popping in/out at full brightness — with randomness=1.0 below staggering
	# every particle's phase, the field reads as a gentle continuous twinkle
	# rather than a fixed pattern.
	mat.color_ramp = _make_fade_ramp(color)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * mote_size
	var surf := StandardMaterial3D.new()
	surf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	surf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf.vertex_color_use_as_albedo = true
	surf.albedo_texture = SoftCircleTexture.make()
	if glow_energy > 0.0:
		surf.emission_enabled = true
		surf.emission = color
		surf.emission_energy_multiplier = glow_energy
	quad.material = surf

	amount = mote_count
	lifetime = 8.0
	preprocess = lifetime   # pre-roll so the field looks lived-in immediately on load,
	                        # not empty for the first lifetime's worth of seconds
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
