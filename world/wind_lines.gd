class_name WindLines
extends GPUParticles3D
## Visible streak-lines that sweep through when a WindGusts.sample() gust
## passes this node's position, instead of the gust only being felt through
## FoliageWind/AmbientMotes reacting to it — this is the thing players
## actually SEE arrive. Silent/empty between gusts (see gust_threshold), then
## bursts a handful of thin trailing streaks across area_size, each one
## following a curling, turbulence-driven path so the line itself visibly
## bends and curves rather than drawing a straight dash.
##
## The bend comes from two things stacked together: GPUParticles3D's own
## trail_enabled (Godot ribbons the line's mesh along each particle's last
## few positions, same built-in feature anything with a motion trail would
## use) riding a path that ParticleProcessMaterial's turbulence noise is
## continuously nudging sideways — a straight trail would just be a static
## dash, the turbulence is what makes that ribbon curve as it travels.
##
## Usage: add as a plain child node in an outdoor area, same idiom as
## AmbientMotes/FoliageWind — see world/hometown.tscn for a worked example.
## `area_size` is the box region lines travel across, centered on this node.

@export var area_size := Vector3(14.0, 3.0, 14.0)
@export var max_lines := 18
@export var line_color := Color(1.0, 1.0, 1.0, 0.35)
@export var line_speed := 5.0          ## world units/sec a line travels at full gust strength
@export var curve_strength := 1.2      ## how hard turbulence bends each line's path
@export var trail_fraction := 0.3      ## 0..1 — how much of a line's travel its visible trail covers
@export var gust_threshold := 1.2      ## only emit once WindGusts.sample() here climbs above this

var _mat: ParticleProcessMaterial

func _ready() -> void:
	_build()
	set_process(true)

func _process(_delta: float) -> void:
	var pos := global_position
	var gust := WindGusts.sample(Vector2(pos.x, pos.z), Time.get_ticks_msec() / 1000.0)
	# Only on during the strong part of a gust — this effect is meant to read
	# as "a gust just swept through", not a constant background streak.
	emitting = gust > gust_threshold
	_mat.initial_velocity_min = line_speed * gust * 0.7
	_mat.initial_velocity_max = line_speed * gust

func _build() -> void:
	var mat := ParticleProcessMaterial.new()
	# Travels along +X like WindGusts' own gust front (see wind_gusts.gd's
	# TRAVEL_SPEED) with a little drift on Z, so the lines visibly move the
	# same direction the gust itself is sweeping, not an unrelated direction.
	mat.direction = Vector3(1.0, 0.0, 0.3)
	mat.spread = 15.0
	mat.initial_velocity_min = line_speed * 0.7
	mat.initial_velocity_max = line_speed
	mat.gravity = Vector3.ZERO
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = area_size * 0.5
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = curve_strength
	mat.turbulence_noise_scale = 1.5
	mat.particle_flag_align_y_to_velocity = true   # orients the streak along its own motion
	mat.color_ramp = _make_fade_ramp(line_color)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.5)   # thin sliver — trail_enabled below stretches it into a line
	var surf := StandardMaterial3D.new()
	surf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf.vertex_color_use_as_albedo = true
	surf.albedo_texture = SoftCircleTexture.make()
	quad.material = surf

	amount = max_lines
	lifetime = area_size.x / maxf(line_speed, 0.01)   # ~ time to cross area_size once
	randomness = 0.6
	local_coords = false
	trail_enabled = true
	trail_lifetime = clampf(trail_fraction, 0.0, 1.0)
	draw_pass_1 = quad
	process_material = mat
	emitting = false   # starts silent; _process() turns it on once a real gust arrives
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
