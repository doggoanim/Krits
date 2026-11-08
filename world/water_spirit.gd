@tool
class_name WaterSpirit
extends Node3D
## A little group of water spirits: three of the animated spirit models
## (assets/npcs/water_spirit.glb, one animation each: spirit_1..3) that orbit and
## bob around a shared centre, always turning to face the camera, with tiny
## drops floating up from them. Everything is built in code in _init() (so the
## models exist the moment the scene is instantiated, which lets
## ModelUtil.fit_height size it when it is held up as an item) and the scene
## (world/water_spirit.tscn) is just this script on a Node3D.
##
## Used in the well where the spirits sleep, and as the model ItemGet holds over
## the player's head when they are collected (ItemLibrary.water_spirits()).

const MODEL := preload("res://assets/npcs/water_spirit.glb")
const ANIMATIONS: Array[StringName] = [&"spirit_1", &"spirit_2", &"spirit_3"]   ## one per spirit
const MODEL_SCALE := 0.45      ## size of each spirit; raise/lower to taste
const FACE_OFFSET := 0.0       ## radians; set to PI if the models end up facing away from the camera
const ORBIT_RADIUS := 0.32
const ORBIT_SPEED := 0.9       ## rad/s
const BOB_HEIGHT := 0.08

var _pivots: Array[Node3D] = []
var _t := 0.0

func _init() -> void:
	for i in ANIMATIONS.size():
		var pivot := Node3D.new()
		pivot.name = "Spirit%d" % i
		add_child(pivot)
		_pivots.append(pivot)
		var model := MODEL.instantiate() as Node3D
		model.scale = Vector3.ONE * MODEL_SCALE
		pivot.add_child(model)
		ModelUtil.apply_cel_shading(model)
		_play(model, ANIMATIONS[i], float(i))
	add_child(_make_drops())
	_place(0.0)

func _process(delta: float) -> void:
	_t += delta
	_place(_t)

## Loops `anim` on the model's AnimationPlayer, started `offset` seconds in so
## the spirits don't move in lockstep.
func _play(model: Node3D, anim: StringName, offset: float) -> void:
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(anim):
		return
	player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	player.play(anim)
	player.seek(offset * 0.7, true)

## Positions every spirit on its orbit and turns it to look at the camera.
func _place(t: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	for i in _pivots.size():
		var pivot := _pivots[i]
		var a := t * ORBIT_SPEED + TAU * float(i) / _pivots.size()
		pivot.position = Vector3(cos(a) * ORBIT_RADIUS, sin(t * 1.7 + i * 2.1) * BOB_HEIGHT, sin(a) * ORBIT_RADIUS)
		if cam != null:
			var to_cam := cam.global_position - pivot.global_position
			pivot.global_rotation.y = atan2(to_cam.x, to_cam.z) + FACE_OFFSET

## Tiny pale drops that float up from the group and shrink away.
func _make_drops() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Drops"
	p.amount = 14
	p.lifetime = 1.8
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = ORBIT_RADIUS
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.4
	p.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.96, 1.0)
	mesh.material = mat
	p.mesh = mesh
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
