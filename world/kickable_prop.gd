@tool
class_name KickableProp
extends RigidBody3D
## A loose prop you can boot around: run or roll into it and it flies off. It sits on its own
## physics layer so it never blocks the player (the kick is an impulse from a nearby sensor),
## but still collides with the world, so it bounces, rolls and settles properly.

enum Kind { BALL, BUCKET }

const KICK_LAYER := 1 << 7                  ## layer 8: loose props (the player doesn't collide with it)
const WORLD_LAYER := 1
const PLAYER_LAYER := 1 << 1
const REACH := 0.5                          ## how far past the prop's own radius the kick sensor reaches
const FALL_RESET_Y := -80.0

@export var kind := Kind.BALL:
	set(v):
		kind = v
		_rebuild()
@export var kick_strength := 1.1            ## impulse per m/s of player speed (x mass)
@export var kick_pop := 3.0                 ## upward speed given to every kick
@export var min_kick_speed := 2.0           ## the player must be moving at least this fast
@export var cooldown := 0.3

var _visual: Node3D
var _sensor: Area3D
var _cool := 0.0
var _home := Transform3D.IDENTITY
var _radius := 0.3

func _ready() -> void:
	_home = global_transform
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_visual = PlayProps.ball() if kind == Kind.BALL else PlayProps.bucket()
	_visual.name = "Visual"
	add_child(_visual)
	var shape := CollisionShape3D.new()
	if kind == Kind.BALL:
		var s := SphereShape3D.new()
		s.radius = 0.28
		shape.shape = s
		shape.position.y = 0.28
		_radius = 0.28
		mass = 0.5
		physics_material_override = _bouncy(0.55, 0.3)
	else:
		var c := CylinderShape3D.new()
		c.radius = 0.22
		c.height = 0.34
		shape.shape = c
		shape.position.y = 0.17
		_radius = 0.22
		mass = 1.2
		physics_material_override = _bouncy(0.15, 0.8)
	add_child(shape)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM   # origin stays at the base; it spins about its middle
	center_of_mass = shape.position
	continuous_cd = true
	collision_layer = KICK_LAYER
	collision_mask = WORLD_LAYER | KICK_LAYER
	freeze = Engine.is_editor_hint()
	if Engine.is_editor_hint():
		return
	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = PLAYER_LAYER
	var sensor_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _radius + REACH
	sensor_shape.shape = sphere
	sensor_shape.position = shape.position
	_sensor.add_child(sensor_shape)
	add_child(_sensor)

static func _bouncy(bounce: float, friction: float) -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = bounce
	m.friction = friction
	return m

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cool = maxf(_cool - delta, 0.0)
	if global_position.y < FALL_RESET_Y:    # fell out of the world: back where it started
		linear_velocity = Vector3.ZERO
		global_transform = _home
		return
	if _cool > 0.0:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or not _sensor.overlaps_body(player):
		return
	var speed := player.get_hvel().length()
	if speed < min_kick_speed:
		return
	var away := global_position - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = player.facing
	away = away.normalized()
	if away.dot(player.get_hvel().normalized()) < 0.2:   # only when running INTO it, not past it
		return
	_cool = cooldown
	linear_velocity = away * speed * kick_strength + Vector3.UP * kick_pop
	angular_velocity = Vector3(away.z, 0.0, -away.x) * speed * 1.5
	var snd: AudioStream = PropSfx.SQUEAK if kind == Kind.BALL else PropSfx.TINK
	PropSfx.play_at(self, snd, global_position, Vector2(1.2, 1.6) if kind == Kind.BALL else Vector2(0.6, 0.8))
