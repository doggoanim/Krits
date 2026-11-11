@tool
class_name KillerFish
extends CharacterBody3D
## A fish that kills the player outright. It drifts around the water it was
## placed in, and the moment it notices a SWIMMING player (not one wading or
## standing on the shore) it winds up for a beat, then darts at them far faster
## than they can swim; touching it is instant death. Get out of the water to
## escape: it gives up as soon as you're not swimming, and it can't leave its
## pool.
##
## Place one: drop a node with this script inside a body of water (it finds the
## WaterVolume under it by itself). The body is built in code, so it also
## shows up in the editor viewport — but nothing is saved into the scene.
## Tuning is all in the exports.

@export var swim_speed := 3.5            ## idle drifting speed
@export var chase_speed := 24.0          ## "extremely fast"
@export var notice_radius := 14.0        ## how far away it spots a swimming player
@export var give_up_radius := 24.0       ## ...and how far you must get before it loses you
@export var windup := 0.4                ## seconds between spotting you and the dart — a sliver of warning
@export var kill_radius := 1.0           ## touching distance (to the player's centre)
@export var wander_radius := 6.0         ## how far from its start it drifts
@export var body_length := 1.8
@export var color := Color(0.75, 0.1, 0.12)

const SURFACE_MARGIN := 0.6              ## keeps its body this far under the surface
const TURN_RATE := 14.0
const KILL_DAMAGE := 1.0e9
const PREVIEW_GROUP_NAME := "KillerFishBody"

enum Mode { WANDER, WINDUP, CHASE }

var _mode := Mode.WANDER
var _home := Vector3.ZERO
var _dest := Vector3.ZERO
var _water: WaterVolume
var _player: Player
var _windup_t := 0.0
var _wait := 0.0
var _age := 0.0
var _body: Node3D
var _tail: Node3D

func _ready() -> void:
	_build_body()
	if Engine.is_editor_hint():
		return
	collision_layer = 1 << 2   # layer 3: enemy, like the other creatures
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_home = global_position
	_dest = _home
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = body_length * 0.3
	shape.shape = sphere
	add_child(shape)

# ---------------------------------------------------------------- the look

## A capsule body lying along its swim direction (-Z), a tail fin behind it,
## two white eyes. Built every time (editor included) and never given an
## owner, so it isn't saved into the scene.
func _build_body() -> void:
	if _body != null:
		return
	_body = Node3D.new()
	_body.name = PREVIEW_GROUP_NAME
	add_child(_body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var capsule := CapsuleMesh.new()
	capsule.radius = body_length * 0.2
	capsule.height = body_length
	var mi := MeshInstance3D.new()
	mi.mesh = capsule
	mi.material_override = mat
	mi.rotation_degrees.x = 90.0
	_body.add_child(mi)
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 0.0, body_length * 0.5)
	_body.add_child(_tail)
	var fin := CylinderMesh.new()
	fin.top_radius = 0.0
	fin.bottom_radius = body_length * 0.22
	fin.height = body_length * 0.4
	var fin_mi := MeshInstance3D.new()
	fin_mi.mesh = fin
	fin_mi.material_override = mat
	fin_mi.rotation_degrees.x = -90.0
	fin_mi.position = Vector3(0.0, 0.0, body_length * 0.2)
	_tail.add_child(fin_mi)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color.WHITE
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = body_length * 0.06
		ball.height = body_length * 0.12
		eye.mesh = ball
		eye.material_override = eye_mat
		eye.position = Vector3(side * body_length * 0.15, body_length * 0.08, -body_length * 0.32)
		_body.add_child(eye)

# ---------------------------------------------------------------- behaviour

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_age += delta
	if _water == null:
		_water = _find_water()
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null or _water == null:
		return
	var swimming := _player.machine.current_name == &"Swim" and _player.current_water() == _water   # swimming, not wading
	match _mode:
		Mode.WANDER:
			_wander(delta)
			if swimming and _dist_to_player() <= notice_radius and not _player.dead:
				_mode = Mode.WINDUP
				_windup_t = windup
				Telegraph.exclaim(self, 1.0)
		Mode.WINDUP:
			_face_player(delta)
			velocity = Vector3.ZERO
			_windup_t -= delta
			if not swimming or _player.dead:
				_mode = Mode.WANDER
			elif _windup_t <= 0.0:
				_mode = Mode.CHASE
		Mode.CHASE:
			if not swimming or _player.dead or _dist_to_player() > give_up_radius:
				_mode = Mode.WANDER
				_dest = _home
			else:
				_chase(delta)
	_wiggle()

func _dist_to_player() -> float:
	return global_position.distance_to(_chest())

func _chest() -> Vector3:
	return _player.global_position + Vector3.UP * (Player.STAND_HEIGHT * 0.5)

func _face_player(delta: float) -> void:
	_turn_toward((_chest() - global_position).normalized(), delta)

func _chase(delta: float) -> void:
	var to := _chest() - global_position
	var dist := to.length()
	if dist <= kill_radius:
		_kill()
		return
	var dir := to / maxf(dist, 0.001)
	_turn_toward(dir, delta)
	# Never overshoot the player in a single step.
	velocity = dir * minf(chase_speed, dist / maxf(delta, 0.0001))
	_swim(delta)
	if _dist_to_player() <= kill_radius:
		_kill()

func _kill() -> void:
	_player.hit(KILL_DAMAGE, true, global_position)
	_mode = Mode.WANDER
	_dest = _home

func _wander(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
		_swim(delta)
		return
	var to := _dest - global_position
	if to.length() < 0.7:
		_wait = randf_range(0.3, 1.2)
		_dest = _pick_dest()
		return
	var dir := to.normalized()
	_turn_toward(dir, delta)
	velocity = dir * swim_speed
	_swim(delta)

func _pick_dest() -> Vector3:
	for _i in 8:
		var a := randf() * TAU
		var r := randf_range(1.0, wander_radius)
		var p := _home + Vector3(cos(a) * r, randf_range(-1.5, 1.5), sin(a) * r)
		if _inside_water(p):
			return p
	return _home

## Moves with `velocity` but never out of the water: a step that would leave
## the pool (sideways past its edge, up through the surface) is trimmed.
func _swim(delta: float) -> void:
	var step := velocity * delta
	if not _inside_water(global_position + step):
		var flat := Vector3(step.x, 0.0, step.z)
		if _inside_water(global_position + flat):
			velocity.y = 0.0
		elif _inside_water(global_position + Vector3(0.0, step.y, 0.0)):
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			velocity = Vector3.ZERO
	move_and_slide()

func _inside_water(pos: Vector3) -> bool:
	return _water.covers_xz(pos) and pos.y + SURFACE_MARGIN <= _water.surface_world_y()

func _find_water() -> WaterVolume:
	for w in WaterVolume.active:
		if w.covers_xz(global_position):
			return w
	return null

func _turn_toward(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var up := Vector3.RIGHT if absf(dir.y) > 0.99 else Vector3.UP
	var target := Transform3D().looking_at(dir, up).basis.get_rotation_quaternion()
	var current := global_transform.basis.get_rotation_quaternion()
	global_transform.basis = Basis(current.slerp(target, minf(1.0, TURN_RATE * delta)))

func _wiggle() -> void:
	if _tail == null:
		return
	var rate := 14.0 if _mode == Mode.CHASE else 5.0
	_tail.rotation.y = sin(_age * rate) * 0.45
