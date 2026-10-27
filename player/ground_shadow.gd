class_name GroundShadow
extends MeshInstance3D
## A small white ring marker on the ground directly below the player —
## hollow, transparent center, just a soft outline — a depth-perception
## aid. Airborne (jumping, diving, falling) it's otherwise easy to lose
## track of exactly how high up you are or where you'll land; this always
## points straight down to the spot you'd land on, growing (up to a cap)
## and fading the higher up you are so it also hints at *how* high.

const SIZE := 0.6                ## marker diameter at ground level (meters)
const RAY_LENGTH := 60.0
const MAX_GROW_HEIGHT := 10.0    ## fully grown/faded by this far above the ground
const MAX_SCALE := 2.2           ## cap — never grows past this multiple of SIZE, however high up
const BASE_ALPHA := 0.8
const MIN_ALPHA := 0.25

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
	_mat.albedo_color = Color(1, 1, 1, 0.8)
	_mat.albedo_texture = SoftCircleTexture.make_ring()
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
	var t := clampf(height / MAX_GROW_HEIGHT, 0.0, 1.0)
	var s := lerpf(1.0, MAX_SCALE, t)
	# The quad is flat in its own local XY plane and only tipped to lie flat
	# via rotation_degrees (-90 around X) — which maps local X straight onto
	# world X, but local Y onto world Z (not local Z, which has no mesh
	# extent at all here). Scaling (s, 1.0, s) — as this used to — left
	# local Y, and with it one of the two ground-plane axes, permanently
	# un-scaled: the ring stayed a fixed width on one axis while growing on
	# the other, stretching into an ellipse instead of a uniform circle the
	# higher up it scaled. Scaling X and Y together (both of which actually
	# land on the ground plane after the rotation) fixes that; Z is left
	# alone since it has nothing to scale.
	scale = Vector3(s, s, 1.0)
	_mat.albedo_color.a = lerpf(BASE_ALPHA, MIN_ALPHA, t)
