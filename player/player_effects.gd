class_name PlayerEffects
extends Node3D
## Procedural movement particle effects — dust, dirt, smoke. Everything here
## (the soft circle sprite, every ParticleProcessMaterial) is built in code,
## no external textures or imported particle scenes, same philosophy as the
## rest of this project.
##
## Two kinds of emitter:
## - Persistent, toggled on/off for as long as a move lasts (running dust,
##   dive smoke trail, long-jump dirt trail). Built once in _ready().
## - One-shot bursts (jump/land dust, wall-bounce and roll-collision
##   impacts): a fresh GPUParticles3D spawned per call and freed once it's
##   done playing, since these are rare, discrete events, not every frame.
##
## All particles use local_coords = false (world-space simulation), so a
## puff stays where it was emitted instead of sliding along with the player
## afterward — that's what turns continuous emission into a trailing effect.

const DUST_RAMP := [
	Color(0.62, 0.5, 0.33, 0.95),
	Color(0.75, 0.72, 0.62, 0.55),
	Color(0.8, 0.8, 0.8, 0.0),
]
const SMOKE_RAMP := [
	Color(0.95, 0.95, 0.97, 0.85),
	Color(0.8, 0.8, 0.85, 0.4),
	Color(0.8, 0.8, 0.85, 0.0),
]

var _dust_texture: GradientTexture2D
var _quad: QuadMesh
var _growth_curve: CurveTexture
var _dust_ramp_tex: GradientTexture1D
var _smoke_ramp_tex: GradientTexture1D

var _run_dust: GPUParticles3D
var _dive_trail: GPUParticles3D
var _long_jump_trail: GPUParticles3D

func _ready() -> void:
	_dust_texture = _make_soft_circle_texture()
	_quad = _make_quad_mesh()
	_growth_curve = _make_growth_curve()
	_dust_ramp_tex = _make_ramp(DUST_RAMP)
	_smoke_ramp_tex = _make_ramp(SMOKE_RAMP)

	_run_dust = _build_emitter(_dust_material(3.0, 6.0, 0.35, 0.8), 14, 0.5, false)
	add_child(_run_dust)
	_dive_trail = _build_emitter(_smoke_material(1.5, -1.5, 0.7, 1.6), 18, 0.8, false)
	add_child(_dive_trail)
	_long_jump_trail = _build_emitter(_dust_material(4.0, 8.0, 0.6, 1.3), 18, 0.55, false)
	add_child(_long_jump_trail)

# ---------------------------------------------------------------- continuous

func set_running_dust(active: bool) -> void:
	_run_dust.emitting = active

func set_dive_trail(active: bool) -> void:
	_dive_trail.emitting = active

func set_long_jump_trail(active: bool) -> void:
	_long_jump_trail.emitting = active

# ---------------------------------------------------------------- one-shot bursts

func burst_jump_dust() -> void:
	_burst(global_position, Vector3.UP, 35.0, _dust_material(4.0, 7.0, 0.3, 0.75), 8, 0.35)

func burst_land_dust() -> void:
	_burst(global_position, Vector3.UP, 60.0, _dust_material(5.5, 9.0, 0.5, 1.2), 16, 0.45)

## `normal` points away from the wall — the airborne dive/long-jump bounce,
## a softer puff of air/smoke since nothing solid hit the ground.
func burst_wall_impact(pos: Vector3, normal: Vector3) -> void:
	_burst(pos, normal, 55.0, _smoke_material(4.0, 0.0, 0.5, 1.1), 12, 0.4)

## Rolling into a wall on the ground — a punchier, dirtier burst than the
## airborne wall bounce above.
func burst_roll_collision(pos: Vector3, normal: Vector3) -> void:
	_burst(pos, normal, 60.0, _dust_material(6.0, 10.0, 0.55, 1.3), 18, 0.45)

# ---------------------------------------------------------------- building blocks

func _burst(pos: Vector3, direction: Vector3, spread_deg: float, mat: ParticleProcessMaterial,
		amount: int, lifetime: float) -> void:
	mat.direction = direction.normalized() if direction.length() > 0.01 else Vector3.UP
	mat.spread = spread_deg
	var p := _build_emitter(mat, amount, lifetime, true)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.restart()
	get_tree().create_timer(lifetime + 0.3).timeout.connect(p.queue_free)

func _build_emitter(mat: ParticleProcessMaterial, amount: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.randomness = 0.4
	p.local_coords = false
	p.draw_pass_1 = _quad
	p.process_material = mat
	p.emitting = false   # continuous emitters wait for set_*(true); bursts are started explicitly below
	return p

func _make_quad_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true   # lets each particle's process-material color tint this
	m.albedo_texture = _dust_texture
	q.material = m
	return q

## A soft white circle, fading to transparent at the edge — built with a
## radial GradientTexture2D instead of an image file.
func _make_soft_circle_texture(size := 32) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

## Particles grow slightly over their lifetime instead of starting at full
## size — reads as dust/smoke expanding rather than a static sprite.
func _make_growth_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.clear_points()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex

func _make_ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var n := colors.size()
	var offsets := PackedFloat32Array()
	for i in n:
		offsets.append(0.0 if n <= 1 else float(i) / float(n - 1))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

## `gravity_y` > 0 pulls particles down (dust settling); < 0 lifts them
## (smoke rising). `scale_min`/`scale_max` are multiples of the 0.4m quad.
func _dust_material(speed: float, gravity_y: float, scale_min: float, scale_max: float) -> ParticleProcessMaterial:
	return _material(speed, gravity_y, scale_min, scale_max, _dust_ramp_tex)

func _smoke_material(speed: float, gravity_y: float, scale_min: float, scale_max: float) -> ParticleProcessMaterial:
	return _material(speed, gravity_y, scale_min, scale_max, _smoke_ramp_tex)

func _material(speed: float, gravity_y: float, scale_min: float, scale_max: float,
		ramp: GradientTexture1D) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 35.0
	m.initial_velocity_min = speed * 0.6
	m.initial_velocity_max = speed
	m.gravity = Vector3(0.0, -gravity_y, 0.0)
	m.damping_min = 1.0
	m.damping_max = 2.5
	m.scale_min = scale_min
	m.scale_max = scale_max
	m.scale_curve = _growth_curve
	m.color_ramp = ramp
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.15
	return m
