class_name GoreBurst
extends Node3D
## A cartoon-gory explosion for when something kills the player outright (the
## killer fish; see Player.gore_death()): a fountain of blood, a red mist, chunks
## of meat and bone that fly out, bounce and leave streaks of blood where they land,
## a spreading stain on the water, and a red flash of light. Everything cleans
## itself up after a while. Visuals only.
##
##   GoreBurst.spawn(parent, position, away_direction, water_surface_y)

const SMOKE_TEXTURE := preload("res://assets/sprites/smoke_puff.png")
const TOON: Shader = preload("res://shading/toon.gdshader")

const BLOOD := Color(0.72, 0.02, 0.06)
const BLOOD_DARK := Color(0.42, 0.0, 0.04)
const MEAT: Array[Color] = [Color(0.8, 0.12, 0.16), Color(0.92, 0.35, 0.4), Color(0.6, 0.06, 0.1), Color(0.95, 0.55, 0.55)]
const BONE := Color(0.95, 0.92, 0.8)
const CLOTH := Color(0.25, 0.45, 0.85)   ## scraps of the player's outfit

const GIB_COUNT := 11
const GIB_GRAVITY := 22.0
const GIB_LIFETIME := 14.0
const SPLAT_LIFETIME := 18.0
const MAX_SPLATS := 70
const GROUND_MASK := 1
const GROUP := &"gore"

static var _splat_texture: Texture2D
static var _splats: Array = []   # untyped: entries can be freed behind our back

var _surface_y := NAN

## `at`: where the body was (its middle). `away`: the direction the blood sprays
## mostly toward (from the killer toward the victim). `surface_y`: the water's
## surface height if this happens over water (a stain spreads there), else NAN.
static func spawn(parent: Node, at: Vector3, away: Vector3, surface_y := NAN) -> GoreBurst:
	var g := GoreBurst.new()
	g._surface_y = surface_y
	g.add_to_group(GROUP)
	parent.add_child(g)
	g.global_position = at
	g._explode(away.normalized() if away.length() > 0.01 else Vector3.UP)
	return g

func _explode(away: Vector3) -> void:
	_flash()
	_spray(away)
	_mist()
	_gibs(away)
	_splash_down()
	if not is_nan(_surface_y):
		_water_stain()
	get_tree().create_timer(GIB_LIFETIME + 4.0).timeout.connect(queue_free)

# ------------------------------------------------------------------ blood

func _unshaded(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if texture != null:
		m.albedo_texture = texture
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _drop_emitter(amount: int, lifetime: float, color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := _unshaded(color)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p.mesh = quad
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

## The fountain: a fan of fast droplets, mostly away from the killer and up.
func _spray(away: Vector3) -> void:
	for layer in [[110, 1.5, BLOOD, 0.16, 5.0, 13.0], [70, 1.1, BLOOD_DARK, 0.24, 3.0, 9.0]]:
		var p := _drop_emitter(layer[0], layer[1], layer[2], layer[3])
		p.direction = (away + Vector3.UP * 0.9).normalized()
		p.spread = 62.0
		p.initial_velocity_min = layer[4]
		p.initial_velocity_max = layer[5]
		p.gravity = Vector3(0.0, -20.0, 0.0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.7
		p.emitting = true
	# a second, upward geyser
	var up := _drop_emitter(60, 1.4, BLOOD, 0.14)
	up.direction = Vector3.UP
	up.spread = 22.0
	up.initial_velocity_min = 7.0
	up.initial_velocity_max = 14.0
	up.gravity = Vector3(0.0, -22.0, 0.0)
	up.emitting = true

## A soft red cloud that billows out and fades.
func _mist() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 1.1
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.4
	var mat := _unshaded(Color(0.75, 0.02, 0.06, 0.8), SMOKE_TEXTURE)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	p.mesh = quad
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3.ZERO
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	p.color_ramp = fade
	add_child(p)
	p.emitting = true

func _flash() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.1, 0.1)
	light.omni_range = 9.0
	light.light_energy = 6.0
	light.shadow_enabled = false
	add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)

# ------------------------------------------------------------------- chunks

func _gibs(away: Vector3) -> void:
	for i in GIB_COUNT:
		var gib := Gib.new()
		gib.setup(i, away, _surface_y)
		add_child(gib)
		gib.top_level = true
		gib.global_position = global_position + Vector3(randf_range(-0.2, 0.2), randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))

## One flying chunk: meat, a bone or a scrap of cloth, tumbling under gravity,
## bouncing off the ground (leaving blood), sinking if it lands in water.
class Gib extends Node3D:
	var _vel := Vector3.ZERO
	var _spin := Vector3.ZERO
	var _surface_y := NAN
	var _settled := false
	var _bounces := 0
	var _age := 0.0
	var _drip: CPUParticles3D

	func setup(index: int, away: Vector3, surface_y: float) -> void:
		_surface_y = surface_y
		var lateral := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		_vel = (away * randf_range(2.0, 7.0) + lateral * randf_range(1.0, 4.0)) + Vector3.UP * randf_range(5.0, 11.0)
		_spin = Vector3(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		var mesh_instance := MeshInstance3D.new()
		var kind := index % 5
		var color: Color
		match kind:
			3:   # bone
				var bone := CylinderMesh.new()
				bone.top_radius = 0.04
				bone.bottom_radius = 0.04
				bone.height = randf_range(0.3, 0.5)
				mesh_instance.mesh = bone
				color = GoreBurst.BONE
			4:   # a scrap of the outfit
				var scrap := BoxMesh.new()
				scrap.size = Vector3(0.28, 0.03, 0.22)
				mesh_instance.mesh = scrap
				color = GoreBurst.CLOTH
			_:   # a lump of meat
				var lump := SphereMesh.new()
				lump.radius = randf_range(0.1, 0.2)
				lump.height = lump.radius * 2.0
				lump.radial_segments = 7
				lump.rings = 4
				mesh_instance.mesh = lump
				mesh_instance.scale = Vector3(randf_range(0.8, 1.5), randf_range(0.6, 1.0), randf_range(0.8, 1.3))
				color = GoreBurst.MEAT[randi() % GoreBurst.MEAT.size()]
		var mat := ShaderMaterial.new()
		mat.shader = GoreBurst.TOON
		mat.set_shader_parameter(&"albedo_texture", ModelUtil.white_texture())
		mat.set_shader_parameter(&"albedo_color", color)
		mat.set_shader_parameter(&"rim_strength", 0.0)
		mesh_instance.material_override = mat
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
		if kind != 3 and kind != 4:
			_drip = CPUParticles3D.new()   # a trail of drops while it flies
			_drip.amount = 14
			_drip.lifetime = 0.6
			_drip.local_coords = false
			var q := QuadMesh.new()
			q.size = Vector2.ONE * 0.1
			var dm := StandardMaterial3D.new()
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dm.albedo_color = GoreBurst.BLOOD
			dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			_drip.mesh = q
			_drip.material_override = dm
			_drip.direction = Vector3.DOWN
			_drip.spread = 40.0
			_drip.initial_velocity_min = 0.2
			_drip.initial_velocity_max = 1.0
			_drip.gravity = Vector3(0.0, -9.0, 0.0)
			_drip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_drip)

	func _physics_process(delta: float) -> void:
		_age += delta
		if _age > GoreBurst.GIB_LIFETIME - 2.0:
			scale = scale.lerp(Vector3.ZERO, clampf(delta * 3.0, 0.0, 1.0))   # shrinks away at the end
		if _age > GoreBurst.GIB_LIFETIME:
			queue_free()
			return
		if _settled:
			return
		var in_water := not is_nan(_surface_y) and global_position.y < _surface_y
		if in_water:
			_vel *= maxf(1.0 - 4.0 * delta, 0.0)       # sinks slowly
			_vel.y = move_toward(_vel.y, -0.7, 30.0 * delta)
			if _drip != null:
				_drip.emitting = false
		else:
			_vel.y -= GoreBurst.GIB_GRAVITY * delta
		var step := _vel * delta
		var hit := _ground_hit(global_position, global_position + step)
		if hit.is_empty():
			global_position += step
			rotation += _spin * delta
			return
		global_position = hit["position"] + hit["normal"] * 0.05
		_bounces += 1
		if not in_water:
			GoreBurst.splat(get_parent(), hit["position"], hit["normal"], randf_range(0.5, 1.2))
		_vel = _vel.bounce(hit["normal"]) * 0.35
		_spin *= 0.5
		if _vel.length() < 1.5 or _bounces >= 4:
			_settled = true
			if _drip != null:
				_drip.emitting = false

	func _ground_hit(from: Vector3, to: Vector3) -> Dictionary:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(from, to, GoreBurst.GROUND_MASK)
		return space.intersect_ray(query)

# --------------------------------------------------------------------- stains

## Removes every burst, chunk, splat and stain at once (on respawn).
static func clear_all(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(GROUP):
		n.queue_free()
	for splat_node in _splats:   # untyped loop var: entries may already be freed
		if is_instance_valid(splat_node):
			splat_node.queue_free()
	_splats.clear()

## A blood splat on a surface (a flat, irregular red blotch that fades).
static func splat(parent: Node, at: Vector3, normal: Vector3, size: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _splat_texture == null:
		_splat_texture = _make_splat_texture()
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _splat_texture
	mat.albedo_color = BLOOD.lerp(BLOOD_DARK, randf() * 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.top_level = true
	var up := normal.normalized()
	var basis := Basis(Quaternion(Vector3.BACK, up))   # the quad faces +Z by default: turn that onto the surface normal
	basis = basis.rotated(up, randf() * TAU)
	mi.global_transform = Transform3D(basis, at + up * 0.025)
	_splats.append(mi)
	while _splats.size() > MAX_SPLATS:
		var old = _splats.pop_front()   # untyped: it may already be freed (a typed var errors on that)
		if is_instance_valid(old):
			old.queue_free()
	var tw := mi.create_tween()
	tw.tween_interval(SPLAT_LIFETIME)
	tw.tween_property(mat, "albedo_color:a", 0.0, 3.0)
	tw.tween_callback(mi.queue_free)

## A burst of splats on the ground right under the body.
func _splash_down() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 6.0, GROUND_MASK)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	splat(get_parent(), hit["position"], hit["normal"], 2.6)
	for i in 7:
		var a := TAU * float(i) / 7.0 + randf() * 0.6
		var p: Vector3 = hit["position"] + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.6, 1.8)
		splat(get_parent(), p, hit["normal"], randf_range(0.5, 1.3))

## Over water: a red stain spreads across the surface and slowly fades.
func _water_stain() -> void:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _splat_texture if _splat_texture != null else (_make_splat_texture())
	_splat_texture = mat.albedo_texture
	mat.albedo_color = Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.75)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.top_level = true
	mi.global_transform = Transform3D(Basis(Quaternion(Vector3.BACK, Vector3.UP)),
			Vector3(global_position.x, _surface_y + 0.05, global_position.z))
	mi.scale = Vector3.ONE * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 7.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 10.0).set_delay(3.0)
	tw.chain().tween_callback(mi.queue_free)

## An irregular blotch with a few satellite droplets, drawn once.
static func _make_splat_texture() -> Texture2D:
	const SIZE := 128
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var satellites: Array[Vector3] = []   # x, y (-1..1), radius
	for i in 7:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.55, 0.85)
		satellites.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(0.04, 0.1)))
	for y in SIZE:
		for x in SIZE:
			var uv := Vector2((float(x) + 0.5) / SIZE * 2.0 - 1.0, (float(y) + 0.5) / SIZE * 2.0 - 1.0)
			var d := uv.length()
			var a := uv.angle()
			var radius := 0.34 + 0.1 * sin(3.0 * a + p1) + 0.07 * sin(5.0 * a + p2) + 0.05 * sin(9.0 * a + p3)
			var alpha := 1.0 - smoothstep(radius - 0.03, radius, d)
			for s in satellites:
				alpha = maxf(alpha, 1.0 - smoothstep(s.z - 0.015, s.z, uv.distance_to(Vector2(s.x, s.y))))
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
