class_name FoliageSteps
extends Node
## Walking through foliage: grass and flowers flatten and lean away from the player's
## feet (the foliage shader reads where the player is, published here as global shader
## parameters), bushes shake while you move inside them, and all of them kick up bits
## (blades, petals, leaves) as you pass.
##
## Which props react is up to FoliageWind, which puts each grass/flower/bush it manages
## in the `steppable_foliage` group and knows its kind and size. This node is the player
## side: created by Player (add it after `visual`), it watches that group.

const PUSH_RADIUS := 0.95            ## how far from the feet the grass leans away
const MIN_SPEED := 1.0               ## m/s along the ground before anything is disturbed
const FULL_SPEED := 6.0              ## speed at which a bush shakes at full strength
const STEP_DISTANCE := 0.6           ## metres moved inside a prop between particle bursts
const ENTER_MARGIN := 0.35           ## extra reach around a prop that already counts as "in" it
const MAX_VERTICAL := 1.4            ## foliage this far above/below the feet is ignored
const MAX_BURSTS := 8                ## particle bursts alive at once (the rest are skipped)

const BLADE_COLORS: Array[Color] = [Color(0.55, 0.85, 0.3), Color(0.4, 0.75, 0.25), Color(0.7, 0.9, 0.4)]
const LEAF_COLORS: Array[Color] = [Color(0.3, 0.62, 0.25), Color(0.4, 0.72, 0.3), Color(0.25, 0.5, 0.22)]

var _player: Player
var _inside := {}          ## foliage instance id -> player position at its last burst
var _bursts_alive := 0
var _radius := 0.0         ## the pusher radius currently published (eases in and out)
var _ellipse: Texture2D

func _ready() -> void:
	_player = get_parent() as Player
	_ellipse = _make_ellipse()

func _exit_tree() -> void:
	_publish(Vector3.ZERO, 0.0)

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var on_ground := _player.is_on_floor() and not _player.dead and _player.machine.current_name != &"Swim"
	_radius = move_toward(_radius, PUSH_RADIUS if on_ground else 0.0, 6.0 * delta)
	_publish(_player.global_position, _radius)
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if not on_ground or speed < MIN_SPEED:
		_inside.clear()
		return
	var now := {}
	for node in get_tree().get_nodes_in_group(FoliageWind.GROUP):
		var wind := node as FoliageWind
		var prop := wind.get_parent() as Node3D
		if prop == null or not prop.is_visible_in_tree():
			continue
		var d := _player.global_position - prop.global_position
		if absf(d.y) > MAX_VERTICAL:
			continue
		var reach := wind.reach + ENTER_MARGIN
		if Vector2(d.x, d.z).length_squared() > reach * reach:
			continue
		var id := wind.get_instance_id()
		now[id] = true
		wind.step_on(speed / FULL_SPEED)
		var last = _inside.get(id)   # null the moment you step into it
		if last == null:
			_burst(wind, prop, true)
			_inside[id] = _player.global_position
		elif (_player.global_position - (last as Vector3)).length() >= STEP_DISTANCE:
			_burst(wind, prop, false)
			_inside[id] = _player.global_position
	for id in _inside.keys():
		if not now.has(id):
			_inside.erase(id)

func _publish(pos: Vector3, radius: float) -> void:
	RenderingServer.global_shader_parameter_set(&"foliage_pusher_pos", pos)
	RenderingServer.global_shader_parameter_set(&"foliage_pusher_radius", radius)

# ---------------------------------------------------------------- particles

## A little puff of blades / petals / leaves from where the player meets the prop.
func _burst(wind: FoliageWind, prop: Node3D, entering: bool) -> void:
	if _bursts_alive >= MAX_BURSTS:
		return
	var at := _player.global_position.lerp(prop.global_position, 0.4) + Vector3.UP * 0.12
	match wind.kind:
		FoliageWind.Kind.GRASS:
			_emit(at, 9 if entering else 5, BLADE_COLORS, Vector2(0.035, 0.17), 3.2, false)
		FoliageWind.Kind.FLOWER:
			var petals: Array[Color] = [wind.petal_color, wind.petal_color.lightened(0.25)]
			_emit(at, 9 if entering else 5, petals, Vector2(0.1, 0.07), 2.6, true)
		FoliageWind.Kind.BUSH:
			_emit(at + Vector3.UP * 0.2, 12 if entering else 6, LEAF_COLORS, Vector2(0.1, 0.16), 3.0, true)

func _emit(pos: Vector3, amount: int, colors: Array[Color], size: Vector2, speed: float, use_ellipse: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.75
	p.local_coords = false
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if use_ellipse:
		mat.albedo_texture = _ellipse
	quad.material = mat
	p.mesh = quad
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -6.0, 0.0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	var palette := Gradient.new()
	var offsets := PackedFloat32Array()
	var packed := PackedColorArray()
	for i in colors.size():
		offsets.append(0.0 if colors.size() == 1 else float(i) / (colors.size() - 1))
		packed.append(colors[i])
	palette.offsets = offsets
	palette.colors = packed
	p.color_initial_ramp = palette
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.4))
	p.scale_amount_curve = shrink
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	_bursts_alive += 1
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(func() -> void:
		_bursts_alive -= 1
		p.queue_free())

## A solid ellipse-able disc: stretched by the quad's own proportions into a petal or leaf.
func _make_ellipse() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 0.95, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
