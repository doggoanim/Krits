class_name PlayerSpeedTrail
extends Node
## Afterimage "ghost" trail for fast moves (roll, dive, long jump) — spawns a
## translucent, fading snapshot of the player's current pose at a steady
## interval while active, left behind in the world as the real player keeps
## moving on. Distinct from PlayerEffects' dust/smoke particles: this is a
## full silhouette copy of the model itself, which reads as raw speed in a
## way a particle trail alone doesn't.
##
## The tricky part is pose: PlayerVisual.get_model() is a rigged,
## Skeleton3D-driven mesh, and simply duplicate()-ing it resets to the
## model's bind pose — a plain duplicate carries no runtime bone state, only
## the static scene structure — so every ghost would look like a T-posed
## statue instead of mid-roll. _copy_skeleton_pose() below copies every
## bone's live transform from the real skeleton onto the ghost's own, so
## each snapshot actually freezes the exact pose at that instant.
##
## Owned by Player (player.gd creates one in _ready(), alongside
## audio/effects/xray) and toggled the same way those are — see
## set_active(), called from RollState/DiveState/LongJumpState.

@export var spawn_interval := 0.06   ## seconds between ghosts while active
@export var fade_time := 0.3         ## how long each ghost takes to fully disappear
@export var color := Color(0.6, 0.85, 1.0, 0.45)   ## tint + starting alpha

var _player: Player
var _active := false
var _spawn_cd := 0.0

func setup(player: Player) -> void:
	_player = player

## Spawns one ghost immediately on activation (rather than waiting out a full
## spawn_interval first) so a short, snappy move like a roll always leaves at
## least one behind, not just longer ones.
func set_active(active: bool) -> void:
	_active = active
	_spawn_cd = 0.0

func _process(delta: float) -> void:
	if not _active or _player == null or _player.visual == null:
		return
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_cd = spawn_interval
		_spawn_ghost()

func _spawn_ghost() -> void:
	var model := _player.visual.get_model()
	var scene_root := _player.get_tree().current_scene
	if model == null or scene_root == null:
		return

	# DUPLICATE_USE_INSTANTIATION re-instances the ghost fresh from the same
	# packed scene (model.scene_file_path, set automatically since it came
	# from PlayerVisual.MODEL_SCENE.instantiate()) instead of deep-copying
	# every node/resource by hand — the right way to clone a scene instance,
	# and what makes _copy_skeleton_pose()'s index-matching below reliable
	# (the duplicate has the exact same internal structure as the original).
	var ghost := model.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	if ghost == null:
		return
	scene_root.add_child(ghost)
	ghost.global_transform = model.global_transform

	_copy_skeleton_pose(model, ghost)
	_stop_animations(ghost)
	var ghost_material := _apply_ghost_material(ghost)

	var tween := ghost.create_tween()
	tween.tween_property(ghost_material, "albedo_color:a", 0.0, fade_time)
	tween.finished.connect(ghost.queue_free)

## Every Skeleton3D found in `src` gets its live bone pose copied onto the
## matching one in `dst` (same traversal order, since `dst` is an identical
## re-instance of the same packed scene as `src`) — without this the ghost
## would reset to the model's bind pose instead of freezing mid-animation.
func _copy_skeleton_pose(src: Node, dst: Node) -> void:
	var src_skeletons := src.find_children("*", "Skeleton3D", true, false)
	var dst_skeletons := dst.find_children("*", "Skeleton3D", true, false)
	for i in src_skeletons.size():
		var from := src_skeletons[i] as Skeleton3D
		var to := dst_skeletons[i] as Skeleton3D
		for b in from.get_bone_count():
			to.set_bone_pose_position(b, from.get_bone_pose_position(b))
			to.set_bone_pose_rotation(b, from.get_bone_pose_rotation(b))
			to.set_bone_pose_scale(b, from.get_bone_pose_scale(b))

## The ghost is a frozen snapshot, not a living animated copy — any
## AnimationPlayer that came along with the duplicate would otherwise keep
## advancing on its own and immediately fight the pose _copy_skeleton_pose()
## just set.
func _stop_animations(node: Node) -> void:
	for anim_player in node.find_children("*", "AnimationPlayer", true, false):
		(anim_player as AnimationPlayer).stop()

## One shared translucent material, unshaded so it reads as a flat colored
## silhouette regardless of scene lighting, on every mesh part of the ghost.
## Returned so the caller can tween its alpha down without hunting for it
## again across however many mesh parts the model has.
func _apply_ghost_material(ghost: Node) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	for mesh_instance in ghost.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).material_override = mat
	return mat
