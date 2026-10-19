class_name PlayerXray
extends Node3D
## Shows a flat, see-through silhouette of the player whenever a wall or
## other piece of world geometry blocks the camera's line of sight to them —
## the common third-person "x-ray" trick so you don't lose track of the
## character behind scenery. Built from duplicates of the player's own
## model meshes (sharing the same skeleton as the original, via
## MeshInstance3D.duplicate(), so they follow the animation automatically
## with no per-frame work needed) rendered unshaded with depth testing
## disabled, toggled visible only while a raycast from the camera to the
## player is actually blocked.

const COLOR := Color(1.0, 1.0, 1.0, 0.5)
const CHECK_INTERVAL := 0.08   ## raycasts aren't free; a handful of checks a second is plenty

var player: Player
var _copies: Array[MeshInstance3D] = []
var _t := 0.0

func setup(p: Player) -> void:
	player = p
	_build_copies(p.visual.get_model())

func _build_copies(model: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = COLOR
	mat.no_depth_test = true   # draws even through whatever's occluding the real model
	mat.render_priority = 10
	_collect(model, mat)

func _collect(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var dup := mi.duplicate() as MeshInstance3D
		dup.material_override = mat
		dup.visible = false
		mi.get_parent().add_child(dup)
		_copies.append(dup)
	for c in n.get_children():
		_collect(c, mat)

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = CHECK_INTERVAL
	var occluded := _is_occluded()
	for c in _copies:
		c.visible = occluded

func _is_occluded() -> bool:
	if player == null or player.camera_rig == null:
		return false
	var cam := player.camera_rig.get_camera()
	if cam == null:
		return false
	var from := cam.global_position
	var to := player.global_position + Vector3.UP * (Player.STAND_HEIGHT * 0.5)
	if from.distance_squared_to(to) < 0.01:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)   # world geometry only
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()
