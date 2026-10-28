class_name MenuHero
extends Node3D
## The pure-white Krits silhouette floating in the menu's void. Wraps the
## same rigged krits.glb the game uses (instanced as the "Model" child in
## menu_stage.tscn, so it's visible/movable in the editor), but with none of
## PlayerVisual's gameplay layers — no lean, expressions, outline pass, or
## state machine — just a pose, a flat white override, and a slow spin/bob.
##
## MenuStage moves THIS node (to slide Krits aside for the title); the spin
## and bob live on the child Model, so the two never fight over a transform.

## Clip names tried in order; the first one the model actually has is played
## on loop. krits.glb has no dedicated menu pose yet — add a clip called
## "main_menu" in Blender and re-export, and it's picked up automatically
## with no code change; until then it falls back to the treading-water pose,
## which reads as floating.
@export var pose_candidates: Array[StringName] = [&"main_menu", &"swimming_idle", &"idle"]
## Standing height in world units, same fit-to-height the game applies.
@export var height := 2.2
@export var spin_speed := 0.6      ## radians/second around Y
@export var bob_height := 0.12     ## world units, up and down
@export var bob_speed := 1.2       ## radians/second of the bob's sine
@export var tilt := 0.07           ## radians, slow forward/back sway

@onready var _model: Node3D = %Model

var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
	var box := ModelUtil.fit_height(_model, height)
	# fit_height reports the pre-scale AABB; recentre so the model's middle —
	# not its feet — sits on this node's origin, which is what makes it appear
	# centred on screen and what the bob/spin pivot around.
	_base_y = -box.get_center().y * _model.scale.y
	_model.position.y = _base_y
	_make_white(_model)
	_play_pose()

func _process(delta: float) -> void:
	_t += delta
	_model.rotation.y += spin_speed * delta
	_model.rotation.x = sin(_t * bob_speed * 0.6) * tilt
	_model.position.y = _base_y + sin(_t * bob_speed) * bob_height

## Replaces every surface's material with flat, unshaded white — "pure
## white" regardless of lighting (there is none in the menu's void), and
## regardless of krits.glb's own emission-driven materials.
func _make_white(root: Node) -> void:
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	_apply_override(root, white)

func _apply_override(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply_override(c, mat)

func _play_pose() -> void:
	var anim := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		push_warning("MenuHero: no AnimationPlayer under the model — it will hold its bind pose.")
		return
	for clip in pose_candidates:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(clip)
			return
	push_warning("MenuHero: none of pose_candidates exist in the model — it will hold its bind pose.")
