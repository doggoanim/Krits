class_name Bullet
extends Area3D
## Simple projectile. `pierces_shield` bullets damage HP directly.

const OUTLINE_THICKNESS := 0.05   ## black inverted-hull outline, see CelOutline

var velocity := Vector3.ZERO
var damage := 8.0
var pierces_shield := false
var lifetime := 6.0
var accel := 0.0          ## speed change per second (0 = constant)
## Optional per-shot color (e.g. a slime ball). Leave at the default (alpha 0)
## to keep the usual pierces_shield-based magenta/orange — most patterns
## don't need to think about color at all.
var color_override := Color(0.0, 0.0, 0.0, 0.0)
var _color := Color(1.0, 0.55, 0.1)

func _ready() -> void:
	collision_layer = 1 << 3   # layer 4: bullet
	collision_mask = 1 << 1    # detect player
	var s := SphereShape3D.new()
	s.radius = 0.28
	var cs := CollisionShape3D.new()
	cs.shape = s
	add_child(cs)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color_override.a > 0.0:
		_color = color_override
	else:
		_color = Color(1.0, 0.1, 0.9) if pierces_shield else Color(1.0, 0.55, 0.1)
	mat.albedo_color = _color
	m.material_override = mat
	add_child(m)
	CelOutline.apply(m, OUTLINE_THICKNESS)
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	if accel != 0.0:
		var spd := maxf(0.0, velocity.length() + accel * delta)
		velocity = velocity.normalized() * spd
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body(body: Node3D) -> void:
	if body is Player:
		(body as Player).hit(damage, pierces_shield, global_position)
		SplashFx.spawn(get_parent(), global_position, _color, velocity)
		queue_free()
