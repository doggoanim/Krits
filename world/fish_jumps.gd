class_name FishJumps
extends Node
## Now and then a fish leaps out of a lake: a small arc, a splash where it leaves and a splash
## where it lands (ripple rings, a spray of droplets, a soft plip). Most at dawn and dusk, rare in
## the middle of the day and the night. The fish are built from FishModel (the same ones you
## catch); the arc is simulated smoothly but shown in held poses (see Choppy).
##
## Point `volume_path` at the lake's WaterVolume (its position, `radius` and `surface_y` give the
## pool). Nothing happens while the player is further than `active_distance` from the lake.

@export var volume_path: NodePath
@export var interval := Vector2(5.0, 12.0)     ## seconds between jumps in the busy hours
@export var quiet_factor := 0.25               ## how much rarer jumps are outside dawn / dusk
@export var busy_hours: Array[Vector2] = [Vector2(5.0, 8.0), Vector2(17.0, 20.0)]
@export var active_distance := 55.0
@export var jump_height := Vector2(0.7, 1.3)
@export var jump_length := Vector2(1.2, 2.2)
@export var jump_time := Vector2(0.75, 1.05)
@export var splash_db := -12.0

const SPECIES := [
	[&"perch", Color(0.45, 0.62, 0.3)], [&"minnow", Color(0.62, 0.7, 0.6)],
	[&"silver_trout", Color(0.7, 0.76, 0.82)], [&"carp", Color(0.82, 0.56, 0.26)],
	[&"rainbow_trout", Color(0.74, 0.58, 0.72)],
]
const SPLASH_SFX := ["res://sounds/SFX/water_splash_1.wav", "res://sounds/SFX/water_splash_2.wav"]
const MAX_AT_ONCE := 2
const RING_LIFE := 1.0

class Leap:
	var fish: Node3D
	var body_scale := Vector3.ONE
	var start := Vector3.ZERO
	var dir := Vector3.RIGHT
	var length := 1.5
	var height := 1.0
	var time := 0.9
	var age := 0.0

class Ring:
	var node: MeshInstance3D
	var age := 0.0
	var size := 0.7

var _volume: WaterVolume
var _leaps: Array[Leap] = []
var _rings: Array[Ring] = []
var _wait := 4.0
var _last_step := -1
var _ring_tex: Texture2D
var _dot_tex: Texture2D
var _sounds: Array[AudioStream] = []
var _last_sound := -1

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_volume = get_node_or_null(volume_path) as WaterVolume
	if _volume == null:
		set_process(false)
		return
	_ring_tex = SoftCircleTexture.make_ring(64)
	_dot_tex = SoftCircleTexture.make(16)
	_sounds = SpatialSfx.load_takes(SPLASH_SFX)
	_wait = randf_range(1.0, interval.y)

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var near := player != null and player.global_position.distance_to(_volume.global_position) < active_distance
	if near and _leaps.size() < MAX_AT_ONCE:
		_wait -= delta
		if _wait <= 0.0:
			_wait = randf_range(interval.x, interval.y) / _activity()
			_start_leap()
	var step := Choppy.index()
	var new_step := step != _last_step
	_last_step = step
	for i in range(_leaps.size() - 1, -1, -1):
		var l := _leaps[i]
		l.age += delta   # the arc runs on real time; the pose is shown below, once per step
		if l.age >= l.time:
			_land(l)
			l.fish.queue_free()
			_leaps.remove_at(i)
		elif new_step:
			_pose(l)
	if new_step:
		_age_rings()

## 1 in the busy hours, `quiet_factor` otherwise.
func _activity() -> float:
	for window in busy_hours:
		if WorldClock.in_range(window.x, window.y):
			return 1.0
	return maxf(quiet_factor, 0.05)

# --- the leap ----------------------------------------------------------------------------

func _surface_y() -> float:
	return _volume.surface_world_y()

func _start_leap() -> void:
	var l := Leap.new()
	var pick: Array = SPECIES[randi() % SPECIES.size()]
	l.fish = FishModel.build(pick[0], pick[1])
	var fish_len := 0.3
	for entry in FishCatalog.FISH:
		if entry["id"] == pick[0]:
			fish_len = entry["length"]
	l.body_scale = Vector3.ONE * fish_len
	var radius := maxf(_volume.radius, 3.0)
	var a := randf() * TAU
	var r := radius * sqrt(randf_range(0.04, 0.5))   # a spot in the middle half of the pool, clear of the shore
	l.start = _volume.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	l.start.y = _surface_y() - 0.1
	var heading := randf() * TAU
	l.dir = Vector3(cos(heading), 0.0, sin(heading))
	l.length = randf_range(jump_length.x, jump_length.y)
	l.height = randf_range(jump_height.x, jump_height.y)
	l.time = randf_range(jump_time.x, jump_time.y)
	add_child(l.fish)
	_pose(l)
	_splash(l.start, 0.8)
	_leaps.append(l)

## Position and heading at the leap's current age: a parabola, nose up then nose down.
func _pose(l: Leap) -> void:
	var u := clampf(l.age / l.time, 0.0, 1.0)
	var pos := l.start + l.dir * l.length * u + Vector3.UP * (4.0 * l.height * u * (1.0 - u))
	var slope := 4.0 * l.height * (1.0 - 2.0 * u) / maxf(l.length, 0.01)
	var tangent := (l.dir + Vector3.UP * slope).normalized()   # the fish swims along +X
	var z := tangent.cross(Vector3.UP).normalized()
	var y := z.cross(tangent)
	l.fish.global_transform = Transform3D(Basis(tangent, y, z) * Basis.from_scale(l.body_scale), pos)

func _land(l: Leap) -> void:
	var at := l.start + l.dir * l.length
	at.y = _surface_y()
	_splash(at, 1.0)

# --- splashes --------------------------------------------------------------------------------

func _splash(at: Vector3, size: float) -> void:
	var surface := Vector3(at.x, _surface_y() + 0.03, at.z)
	var ring := Ring.new()
	ring.size = 0.8 * size
	ring.node = _quad(_ring_tex, Vector2.ONE, Color(0.85, 1.0, 1.0, 0.7))
	add_child(ring.node)
	ring.node.global_position = surface
	ring.node.rotation_degrees.x = -90.0
	ring.node.scale = Vector3.ONE * 0.05
	_rings.append(ring)
	_spray(surface, size)
	if not _sounds.is_empty():
		_last_sound = SpatialSfx.pick(_sounds.size(), _last_sound)
		SpatialSfx.play(self, _sounds[_last_sound], surface, splash_db, Vector2(1.5, 1.9), 40.0, 6.0)

func _age_rings() -> void:
	for i in range(_rings.size() - 1, -1, -1):
		var r := _rings[i]
		r.age += Choppy.STEP_SECONDS
		var k := r.age / RING_LIFE
		if k >= 1.0:
			r.node.queue_free()
			_rings.remove_at(i)
			continue
		r.node.scale = Vector3.ONE * lerpf(0.05, r.size, 1.0 - pow(1.0 - k, 2.0))
		var mat := (r.node.mesh as QuadMesh).material as StandardMaterial3D
		mat.albedo_color = Color(0.85, 1.0, 1.0, 0.7 * (1.0 - k))

func _spray(at: Vector3, size: float) -> void:
	var p := CPUParticles3D.new()
	p.fixed_fps = Choppy.particle_fps()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(8.0 * size) + 4
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -7.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.07
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _dot_tex
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.9)
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

func _quad(tex: Texture2D, size: Vector2, color: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = color
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
