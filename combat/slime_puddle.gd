class_name SlimePuddle
extends Area3D
## A patch of slime left on the ground (by Enemy.leaves_puddle_trail). While
## the player stands in it: periodic damage, slowed ground speed and no
## jumping (see Player.enter_slime_puddle/exit_slime_puddle), plus the green
## "slimed" look and dripping particles on the player themselves. Grows in,
## sits for `lifetime`, then shrinks away and frees itself.

const GROW_TIME := 0.25
const FADE_TIME := 0.6
const GROUND_CLEARANCE := 0.08   ## lifts the flat quad above the ground it's drawn on,
                                  ## well clear of z-fighting/clipping on uneven terrain
                                  ## (bigger than GroundShadow's 0.02 since this also has
                                  ## to survive the enemy's own ground-probe margin of error)

@export var radius := 1.3
@export var color := Color(0x5A / 255.0, 0x8B / 255.0, 0x2F / 255.0)
@export var damage := 4.0
@export var tick_interval := 0.9
@export var lifetime := 5.0

var _player: Player
var _tick_t := 0.0
var _life_t := 0.0
var _mesh: MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1   # layer 2: player
	monitorable = false
	monitoring = false   # turned on once the grow tween finishes, below

	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.0
	cs.shape = shape
	add_child(cs)

	# The grow/fade animation scales only this mesh, never `self` — this node
	# (an Area3D) owns the CollisionShape3D above, and the physics server
	# can't invert a zero-scale transform, which a scale-0 Area3D would hand
	# it the instant this spawns.
	#
	# A real flat CylinderMesh instead of a textured quad: its edge is the
	# actual geometric rim of the circle, not a soft alpha falloff baked into
	# a texture — so the puddle reads as one solid flat color with a crisp
	# boundary, no gradient or blur.
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	_mesh.mesh = cyl
	_mesh.position.y = GROUND_CLEARANCE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	_mesh.material_override = mat
	add_child(_mesh)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_mesh.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3.ONE, GROW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): monitoring = true)

func _physics_process(delta: float) -> void:
	_life_t += delta
	if _life_t >= lifetime:
		_dissolve()
		return
	if _player:
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = tick_interval
			_player.hit(damage)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body
		_tick_t = 0.0   # damage right away on stepping in, then every tick_interval after
		_player.enter_slime_puddle(color)

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player.exit_slime_puddle()
		_player = null

func _dissolve() -> void:
	set_physics_process(false)
	monitoring = false
	if _player:
		_player.exit_slime_puddle()
		_player = null
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3.ZERO, FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
