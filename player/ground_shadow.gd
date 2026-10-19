class_name GroundShadow
extends MeshInstance3D
## A small soft circle marker on the ground directly below the player — a
## depth-perception aid. Airborne (jumping, diving, falling) it's otherwise
## easy to lose track of exactly how high up you are or where you'll land;
## this always points straight down to the spot you'd land on, shrinking
## and fading the higher up you are so it also hints at *how* high.

const SIZE := 0.6                ## marker diameter at ground level (meters)
const RAY_LENGTH := 60.0
const MAX_FADE_HEIGHT := 10.0    ## fully shrunk/faded by this far above the ground
const MIN_SCALE := 0.35          ## never shrinks smaller than this fraction of SIZE
const MIN_ALPHA := 0.15

var player: Player
var _mat: StandardMaterial3D

func setup(p: Player) -> void:
	player = p
	top_level = true   # position in world space — never inherit the player's own rotation/scale
	var q := QuadMesh.new()
	q.size = Vector2(SIZE, SIZE)
	mesh = q
	rotation_degrees = Vector3(-90, 0, 0)   # lie flat, facing up
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(0, 0, 0, 0.55)
	_mat.albedo_texture = SoftCircleTexture.make()
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material_override = _mat

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var space := player.get_world_3d().direct_space_state
	var from := player.global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * RAY_LENGTH, 1)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	visible = true
	var hit_pos: Vector3 = hit.position
	global_position = hit_pos + Vector3.UP * 0.02   # avoid z-fighting with the floor
	var height := from.y - hit_pos.y
	var t := clampf(height / MAX_FADE_HEIGHT, 0.0, 1.0)
	var s := lerpf(1.0, MIN_SCALE, t)
	scale = Vector3(s, 1.0, s)
	_mat.albedo_color.a = lerpf(0.55, MIN_ALPHA, t)
