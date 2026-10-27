class_name FallingLeaves
extends GPUParticles3D
## A slow drift of leaves falling from a tree canopy — same bolt-on idiom as
## AmbientMotes/FoliageWind: drop this as a plain child node near/under a
## tree and it runs on its own. Leaves spawn throughout area_size and
## fall/tumble down through it, looping continuously — add several with
## different area_size/leaf_color under different trees rather than one
## giant field over the whole level, so it reads as coming from a
## particular canopy instead of raining everywhere at once.
##
## No leaf texture asset exists yet — this reuses the same soft round
## sprite AmbientMotes' dust uses, just stretched into a small oval and
## tinted; billboard spin (angular_velocity on a camera-facing billboard)
## gives it the fluttering tumble a falling leaf actually has, rather than
## dropping face-first in a straight line. Reacts to WindGusts the same way
## AmbientMotes does, so a gust visibly carries the leaves sideways with it.
##
## cull_distance makes it cheap to drop one of these under every tree in a
## large forest instead of hand-picking a few: past that distance from the
## active camera, it stops emitting/simulating/drawing entirely rather than
## running 200 of these at once regardless of how many are actually in view.
## 0 disables culling (the default for a level with only a couple of these).

@export var area_size := Vector3(6.0, 5.0, 6.0)
@export var leaf_count := 20
@export var leaf_color := Color(0.75, 0.45, 0.15, 0.9)   ## autumn orange-brown default
@export var leaf_size := Vector2(0.09, 0.14)
@export var fall_speed := 0.7
@export var sway_strength := 0.35      ## how much turbulence pushes leaves side to side on the way down
@export var tumble_speed := 90.0       ## degrees/sec billboard spin, randomized up to this per leaf
@export var react_to_gusts := true
@export var cull_distance := 0.0       ## >0: stop simulating/drawing past this distance from the camera

var _mat: ParticleProcessMaterial
var _culled := false

func _ready() -> void:
	_build()
	set_process(true)

func _process(_delta: float) -> void:
	if cull_distance > 0.0:
		var cam := get_viewport().get_camera_3d()
		var far := cam != null and global_position.distance_to(cam.global_position) > cull_distance
		if far != _culled:
			_culled = far
			visible = not far
			emitting = not far
		if far:
			return   # nothing else to update while culled — skip the gust sample too
	if not react_to_gusts:
		return
	var pos := global_position
	var gust := WindGusts.sample(Vector2(pos.x, pos.z), Time.get_ticks_msec() / 1000.0)
	_mat.turbulence_noise_strength = sway_strength * gust

func _build() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.DOWN
	mat.spread = 15.0
	mat.initial_velocity_min = fall_speed * 0.6
	mat.initial_velocity_max = fall_speed
	mat.gravity = Vector3(0.0, -0.3, 0.0)   # a gentle extra pull, not a real plummet — leaves drift down
	mat.damping_min = 0.0
	mat.damping_max = 0.2
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = area_size * 0.5
	mat.scale_min = 0.8
	mat.scale_max = 1.3
	mat.angular_velocity_min = -tumble_speed
	mat.angular_velocity_max = tumble_speed
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = sway_strength
	mat.turbulence_noise_scale = 1.5
	mat.color_ramp = _make_fade_ramp(leaf_color)

	var quad := QuadMesh.new()
	quad.size = leaf_size
	var surf := StandardMaterial3D.new()
	surf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED   # angular_velocity then reads as an in-plane spin/flutter
	surf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf.vertex_color_use_as_albedo = true
	surf.albedo_texture = SoftCircleTexture.make()
	quad.material = surf

	amount = leaf_count
	lifetime = area_size.y / maxf(fall_speed, 0.05)
	preprocess = lifetime   # pre-roll so leaves are already mid-fall on load, not all starting at the top at once
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
