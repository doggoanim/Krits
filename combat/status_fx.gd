class_name StatusFx
extends Node3D
## The visuals for an enemy's magic status effects, attached to the Enemy
## (see Enemy.apply_burn/apply_slow/apply_stun). Each effect is on or off:
##   burn  — rising flame sparks, a flickering warm light and an orange pulse
##   slow  — drifting frost flakes, a cold mist and a steady icy blue tint
##   stun  — rocks circling the head and a wobbly earthy tint
## The body tint goes to EnemyVisual.set_status_tint() (model enemies only);
## the particles and orbiting rocks work on every enemy.

const BURN_COLOR := Color(1.0, 0.5, 0.12)
const SLOW_COLOR := Color(0.45, 0.8, 1.0)
const STUN_COLOR := Color(0.7, 0.5, 0.25)

var _active := {&"burn": false, &"slow": false, &"stun": false}
var _burn: GPUParticles3D
var _burn_light: OmniLight3D
var _frost: GPUParticles3D
var _mist: GPUParticles3D
var _orbit: Node3D
var _visual: EnemyVisual
var _t := 0.0
var _radius := 0.5
var _body_height := 1.4

## `center` is the body's middle in the enemy's local space.
func setup(visual: EnemyVisual, center_y: float, body_height: float, body_radius: float) -> void:
	_visual = visual
	position = Vector3(0.0, center_y, 0.0)
	_radius = maxf(body_radius, 0.3)
	_body_height = body_height
	_build_burn()
	_build_frost()
	_build_orbit()

func set_active(effect: StringName, on: bool) -> void:
	if _active.get(effect, false) == on:
		return
	_active[effect] = on
	match effect:
		&"burn":
			_burn.emitting = on
			_burn_light.visible = on
		&"slow":
			_frost.emitting = on
			_mist.emitting = on
		&"stun":
			_orbit.visible = on

func clear_all() -> void:
	for effect in _active:
		set_active(effect, false)
	if _visual:
		_visual.set_status_tint(Color.WHITE, 0.0)

func _process(delta: float) -> void:
	_t += delta
	if _active[&"stun"]:
		_orbit.rotation.y += delta * 5.0
		_orbit.position.y = _body_height * 0.5 + 0.15 + sin(_t * 4.0) * 0.05
	if _active[&"burn"]:
		_burn_light.light_energy = 1.6 + sin(_t * 31.0) * 0.5 + sin(_t * 17.0) * 0.4
	_update_tint()

func _update_tint() -> void:
	if _visual == null:
		return
	if _active[&"burn"]:
		_visual.set_status_tint(BURN_COLOR, 0.5 + 0.2 * sin(_t * 14.0))
	elif _active[&"stun"]:
		_visual.set_status_tint(STUN_COLOR, 0.35 + 0.15 * sin(_t * 9.0))
	elif _active[&"slow"]:
		_visual.set_status_tint(SLOW_COLOR, 0.55)
	else:
		_visual.set_status_tint(Color.WHITE, 0.0)

# ---------------------------------------------------------------- builders

func _build_burn() -> void:
	var mat := _particle_material(Vector3.UP, 20.0, 1.0, 2.4, Vector3(0, 3.0, 0), 0.7, 1.5)
	mat.color_ramp = _ramp([Color(1.0, 0.95, 0.4), Color(1.0, 0.5, 0.1), Color(0.8, 0.1, 0.05, 0.0)])
	_burn = _emitter(mat, 26, 0.75, _spark_mesh(Vector3.ONE * 0.16))
	add_child(_burn)
	_burn_light = OmniLight3D.new()
	_burn_light.light_color = BURN_COLOR
	_burn_light.omni_range = 4.0
	_burn_light.shadow_enabled = false
	_burn_light.visible = false
	add_child(_burn_light)

func _build_frost() -> void:
	var flakes := _particle_material(Vector3.DOWN, 180.0, 0.2, 0.7, Vector3(0, -1.0, 0), 0.6, 1.3)
	flakes.color_ramp = _ramp([Color(0.95, 1.0, 1.0), Color(0.5, 0.85, 1.0), Color(0.4, 0.75, 1.0, 0.0)])
	flakes.angular_velocity_min = -200.0
	flakes.angular_velocity_max = 200.0
	_frost = _emitter(flakes, 16, 1.2, _spark_mesh(Vector3(0.14, 0.14, 0.14)))
	add_child(_frost)
	# A softer, bigger, slower layer for the "cold air" read.
	var mist := _particle_material(Vector3.UP, 60.0, 0.1, 0.4, Vector3(0, 0.3, 0), 2.5, 4.0)
	mist.color_ramp = _ramp([Color(0.7, 0.9, 1.0, 0.35), Color(0.7, 0.9, 1.0, 0.15), Color(0.7, 0.9, 1.0, 0.0)])
	_mist = _emitter(mist, 8, 1.4, _spark_mesh(Vector3.ONE * 0.2))
	add_child(_mist)

## Three rocks circling above the head.
func _build_orbit() -> void:
	_orbit = Node3D.new()
	_orbit.visible = false
	add_child(_orbit)
	for i in 3:
		var rock := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.2, 0.22)
		rock.mesh = box
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.55, 0.35, 0.15)
		rock.material_override = m
		var ang := TAU * float(i) / 3.0
		rock.position = Vector3(cos(ang), 0.0, sin(ang)) * (_radius + 0.15)
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_orbit.add_child(rock)
		CelOutline.apply(rock, 0.03)
	_orbit.position.y = _body_height * 0.5 + 0.15

func _particle_material(direction: Vector3, spread: float, vmin: float, vmax: float,
		gravity: Vector3, smin: float, smax: float) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = direction
	mat.spread = spread
	mat.initial_velocity_min = vmin
	mat.initial_velocity_max = vmax
	mat.gravity = gravity
	mat.scale_min = smin
	mat.scale_max = smax
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = _radius * 0.9
	return mat

func _emitter(mat: ParticleProcessMaterial, amount: int, lifetime: float, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.draw_pass_1 = mesh
	p.process_material = mat
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func _spark_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	b.material = m
	return b

func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(0.0 if colors.size() <= 1 else float(i) / float(colors.size() - 1))
	g.offsets = offsets   # offsets before colors, same order VFX._make_ramp() uses
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
