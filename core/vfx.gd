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
static var _shard_mesh: BoxMesh
static var _ring_quad: QuadMesh
static var _ring_texture: Texture2D

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

## A burst of small angular shards flying outward in every direction, then
## tumbling and falling under gravity — something breaking/shattering (an orb
## popping, a breakable crystal, ...), as opposed to smoke_puff's soft billowy
## cloud. `color` tints the shards (faded out via color_ramp's alpha, not a
## shrink, so the unshaded flat-color style stays crisp right up to the end);
## `scale` multiplies both shard size and burst speed.
static func shatter(parent: Node3D, pos: Vector3, color: Color, scale := 1.0) -> void:
	_ensure_resources()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 180.0   # full sphere, not a cone — shards fly every which way
	mat.initial_velocity_min = 2.5 * scale
	mat.initial_velocity_max = 5.5 * scale
	mat.gravity = Vector3(0.0, -9.0, 0.0)
	mat.damping_min = 0.4
	mat.damping_max = 1.2
	mat.angular_velocity_min = -720.0
	mat.angular_velocity_max = 720.0
	mat.scale_min = 0.5 * scale
	mat.scale_max = 1.1 * scale
	mat.color_ramp = _make_ramp([color, color, Color(color.r, color.g, color.b, 0.0)])
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15 * scale

	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.3
	p.local_coords = false
	p.draw_pass_1 = _shard_mesh
	p.process_material = mat
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.restart()
	parent.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

## A flat ring shockwave at `pos`, expanding and fading over a third of a
## second — the landing-impact companion to smoke_puff/shatter above. Unlike
## those two, this isn't a particle burst (a ring reads better as one clean
## shape than a cloud of them), just a single quad tweened directly: scale up
## with an ease-out, alpha down, then free itself. `scale` sizes the ring —
## pass something derived from fall speed so a harder landing visibly leaves
## a bigger ring, same idiom as smoke_puff/shatter's own `scale` param.
static func landing_ring(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	_ensure_resources()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _ring_quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _ring_texture
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.6)
	mesh_inst.material_override = mat
	parent.add_child(mesh_inst)
	mesh_inst.global_position = pos + Vector3.UP * 0.02   # clear z-fighting with the ground underneath
	mesh_inst.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # lay flat, facing up
	mesh_inst.scale = Vector3.ONE * 0.3 * scale

	var tween := mesh_inst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3.ONE * 1.8 * scale, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.finished.connect(mesh_inst.queue_free)

static func _ensure_resources() -> void:
	if _smoke_quad != null:
		return
	_smoke_quad = _make_quad_mesh(load(SMOKE_TEXTURE_PATH))
	_smoke_ramp = _make_ramp([
		Color(0.95, 0.95, 0.97, 0.85),
		Color(0.8, 0.8, 0.85, 0.4),
		Color(0.8, 0.8, 0.85, 0.0),
	])
	_shard_mesh = _make_shard_mesh()
	_ring_quad = QuadMesh.new()
	_ring_quad.size = Vector2.ONE
	_ring_texture = SoftCircleTexture.make_ring(64)

static func _make_shard_mesh() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE * 0.12
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	b.material = m
	return b

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
