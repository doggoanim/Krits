class_name PlayerEffects
extends Node3D
## Movement particle effects — dust, dirt, smoke. Every ParticleProcessMaterial
## is built in code, but the sprite each particle wears is one of two hand-
## drawn textures (assets/sprites/): dirt_texture.png for anything dust/dirt,
## smoke_puff.png for anything smoke/air.
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
## Alpha stops for the slime drip's ramp — the color itself is whatever
## SlimePuddle the player is currently standing in uses (see set_slime_drip()),
## not a fixed constant, so it always matches that puddle instead of one
## hardcoded green.
const SLIME_DRIP_ALPHAS := [0.9, 0.6, 0.0]

const DUST_TEXTURE_PATH := "res://assets/sprites/dirt_texture.png"
const SMOKE_TEXTURE_PATH := "res://assets/sprites/smoke_puff.png"

var _dust_quad: QuadMesh
var _smoke_quad: QuadMesh
var _growth_curve: CurveTexture
var _dust_ramp_tex: GradientTexture1D
var _smoke_ramp_tex: GradientTexture1D
var _slime_drip_material: ParticleProcessMaterial   ## kept so set_slime_drip() can swap its color_ramp

var _run_dust: GPUParticles3D
var _dive_trail: GPUParticles3D
var _long_jump_trail: GPUParticles3D
var _slime_drip: GPUParticles3D

func _ready() -> void:
	_dust_quad = _make_quad_mesh(load(DUST_TEXTURE_PATH))
	_smoke_quad = _make_quad_mesh(load(SMOKE_TEXTURE_PATH))
	_growth_curve = _make_growth_curve()
	_dust_ramp_tex = _make_ramp(DUST_RAMP)
	_smoke_ramp_tex = _make_ramp(SMOKE_RAMP)

	_run_dust = _build_emitter(_dust_material(3.0, 6.0, 0.35, 0.8), 14, 0.5, false, _dust_quad)
	add_child(_run_dust)
	_dive_trail = _build_emitter(_smoke_material(1.5, -1.5, 0.7, 1.6), 18, 0.8, false, _smoke_quad)
	add_child(_dive_trail)
	_long_jump_trail = _build_emitter(_dust_material(4.0, 8.0, 0.6, 1.3), 18, 0.55, false, _dust_quad)
	add_child(_long_jump_trail)
	_slime_drip_material = _slime_drip_material_for(PlayerVisual.SLIME_TINT_COLOR)
	_slime_drip = _build_emitter(_slime_drip_material, 10, 0.6, false, _dust_quad)
	_slime_drip.position.y = 1.0   # emit from around the torso, not the feet, so it reads as dripping off the character
	add_child(_slime_drip)

# ---------------------------------------------------------------- continuous

func set_running_dust(active: bool) -> void:
	_run_dust.emitting = active

func set_dive_trail(active: bool) -> void:
	_dive_trail.emitting = active

func set_long_jump_trail(active: bool) -> void:
	_long_jump_trail.emitting = active

## Driven by Player.enter_slime_puddle/exit_slime_puddle, alongside
## PlayerVisual.set_slimed — the green tint and the drip particles always
## turn on and off together. `color` is the specific puddle's own color
## (passed through from SlimePuddle.color, which varies per enemy), so the
## drip is recolored to match it each time — not a fixed green regardless of
## which puddle the player is actually standing in.
func set_slime_drip(active: bool, color := PlayerVisual.SLIME_TINT_COLOR) -> void:
	if active:
		# A fresh GradientTexture1D each time, rather than mutating the
		# existing one's Gradient in place and hoping the running
		# GPUParticles3D notices — assigning a whole new resource to the
		# material's color_ramp is the one change that's guaranteed to show
		# up, including on particles already mid-flight.
		_slime_drip_material.color_ramp = _make_ramp(_slime_drip_colors(color))
	_slime_drip.emitting = active

# ---------------------------------------------------------------- one-shot bursts

func burst_jump_dust() -> void:
	_burst(global_position, Vector3.UP, 35.0, _dust_material(4.0, 7.0, 0.3, 0.75), 8, 0.35, _dust_quad)

func burst_land_dust() -> void:
	_burst(global_position, Vector3.UP, 60.0, _dust_material(5.5, 9.0, 0.5, 1.2), 16, 0.45, _dust_quad)

## `normal` points away from the wall — the airborne dive/long-jump bounce,
## a softer puff of air/smoke since nothing solid hit the ground.
func burst_wall_impact(pos: Vector3, normal: Vector3) -> void:
	_burst(pos, normal, 55.0, _smoke_material(4.0, 0.0, 0.5, 1.1), 12, 0.4, _smoke_quad)

## Rolling into a wall on the ground — a punchier, dirtier burst than the
## airborne wall bounce above.
func burst_roll_collision(pos: Vector3, normal: Vector3) -> void:
	_burst(pos, normal, 60.0, _dust_material(6.0, 10.0, 0.55, 1.3), 18, 0.45, _dust_quad)

# ---------------------------------------------------------------- building blocks

func _burst(pos: Vector3, direction: Vector3, spread_deg: float, mat: ParticleProcessMaterial,
		amount: int, lifetime: float, quad: QuadMesh) -> void:
	mat.direction = direction.normalized() if direction.length() > 0.01 else Vector3.UP
	mat.spread = spread_deg
	var p := _build_emitter(mat, amount, lifetime, true, quad)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.restart()
	get_tree().create_timer(lifetime + 0.3).timeout.connect(p.queue_free)

func _build_emitter(mat: ParticleProcessMaterial, amount: int, lifetime: float, one_shot: bool,
		quad: QuadMesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.randomness = 0.4
	p.local_coords = false
	p.draw_pass_1 = quad
	p.process_material = mat
	p.emitting = false   # continuous emitters wait for set_*(true); bursts are started explicitly below
	return p

func _make_quad_mesh(texture: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true   # lets each particle's process-material color tint this
	m.albedo_texture = texture
	q.material = m
	return q

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

## Builds the drip's 3-stop fade-out ramp (start visible, dim, fully
## transparent — same alpha curve regardless of color) for whichever puddle
## color is currently active. See set_slime_drip().
func _slime_drip_colors(color: Color) -> Array:
	return [
		Color(color.r, color.g, color.b, 0.9),
		Color(color.r, color.g, color.b, 0.6),
		Color(color.r, color.g, color.b, 0.0),
	]

## Small droplets falling straight down off the body — unlike every other
## emitter here (all UP-biased, dust kicked up or smoke rising), this one
## needs its own direction, so it doesn't go through _material() above.
## `color` seeds its initial ramp; set_slime_drip() swaps color_ramp directly
## on the returned material afterward whenever the active puddle changes.
func _slime_drip_material_for(color: Color) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.DOWN
	m.spread = 20.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.8
	m.gravity = Vector3(0.0, -4.0, 0.0)
	m.damping_min = 0.5
	m.damping_max = 1.5
	m.scale_min = 0.25
	m.scale_max = 0.5
	m.scale_curve = _growth_curve
	m.color_ramp = _make_ramp(_slime_drip_colors(color))
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.35
	return m
