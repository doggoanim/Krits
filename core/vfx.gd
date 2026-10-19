class_name VFX
extends RefCounted
## Shared one-shot visual effects usable from any Node3D context — unlike
## PlayerEffects (which only exists attached to the player), these are plain
## static helpers any system can call directly, so e.g. WorldEnemy's pop-in
## doesn't need its own bespoke particle-building code. Add more one-shot
## bursts here as other systems need them.

const SMOKE_TEXTURE_PATH := "res://assets/sprites/smoke_puff.png"

static var _smoke_quad: QuadMesh
static var _smoke_ramp: GradientTexture1D

## A puff of smoke at `pos`, parented under `parent` so it's cleaned up if
## `parent` is (freed itself once its particles finish). `scale` multiplies
## both the burst's size and speed — pass an enemy's own `data.size`, say,
## so a bigger enemy gets a bigger puff.
static func smoke_puff(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	_ensure_resources()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 50.0
	mat.initial_velocity_min = 2.0 * scale
	mat.initial_velocity_max = 4.0 * scale
	mat.gravity = Vector3(0.0, 1.0, 0.0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.8 * scale
	mat.scale_max = 1.6 * scale
	mat.color_ramp = _smoke_ramp
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2 * scale

	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.randomness = 0.4
	p.local_coords = false
	p.draw_pass_1 = _smoke_quad
	p.process_material = mat
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.restart()
	parent.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

static func _ensure_resources() -> void:
	if _smoke_quad != null:
		return
	_smoke_quad = _make_quad_mesh(load(SMOKE_TEXTURE_PATH))
	_smoke_ramp = _make_ramp([
		Color(0.95, 0.95, 0.97, 0.85),
		Color(0.8, 0.8, 0.85, 0.4),
		Color(0.8, 0.8, 0.85, 0.0),
	])

static func _make_quad_mesh(texture: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture
	q.material = m
	return q

static func _make_ramp(colors: Array) -> GradientTexture1D:
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
