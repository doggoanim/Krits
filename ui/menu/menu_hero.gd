class_name MenuHero
extends Node3D
## The pure-white Krits silhouette floating in the menu's void. Wraps the
## same rigged krits.glb the game uses (instanced as the "Model" child in
## menu_stage.tscn, so it's visible/movable in the editor), but with none of
## PlayerVisual's gameplay layers — no lean, expressions, outline pass, or
## state machine — just a pose, a flat white override, and a slow zero-g
## tumble/bob.
##
## MenuStage moves THIS node (to slide Krits aside for the title); the
## tumble and bob live on the child Pivot, so the two never fight over a
## transform.

## The menu pose: the first clip below the model actually has is played on
## loop. Matching is forgiving — case, spaces, underscores and hyphens are
## ignored ("Main Menu", "main-menu" and "main_menu" all match), and failing
## an exact match any clip with "menu" in its name is used. If nothing menu-
## like exists it falls back to plain idle (and warns, listing every clip in
## the model so a misnamed one is easy to spot).
@export var pose_candidates: Array[StringName] = [&"main_menu", &"idle"]
## Standing height in world units, same fit-to-height the game applies.
@export var height := 2.2
## Free-floating tumble, radians/second around each axis (X, Y, Z). The three
## differ on purpose so the combined motion never repeats in an obvious loop
## and he slowly passes through every orientation, like drifting in zero-g.
## Set to (0, 0.6, 0) for a plain turntable spin instead.
@export var tumble_speed := Vector3(0.25, 0.6, 0.15)
@export var bob_height := 0.12     ## world units, up and down
@export var bob_speed := 1.2       ## radians/second of the bob's sine

## The Pivot is what tumbles and bobs; the Model is offset inside it so his
## centre of mass — not his feet — sits on the pivot's origin. That's what
## makes him rotate in place around his middle instead of swinging around
## his feet like a pendulum.
@onready var _pivot: Node3D = %Pivot
@onready var _model: Node3D = %Model

var _angles := Vector3.ZERO
var _t := 0.0

func _ready() -> void:
	var box := ModelUtil.fit_height(_model, height)
	# fit_height reports the pre-scale AABB. Shift the model by minus its
	# (scaled) centre so the middle of his body is the pivot's origin.
	_model.position = -box.get_center() * _model.scale.x
	_make_white(_model)
	_play_pose()

func _process(delta: float) -> void:
	_t += delta
	# Euler angles accumulated by hand (rather than rotate_x/y/z on the
	# basis) so there's no drift to correct, and `rotation` leaves the
	# model's fit-to-height scale untouched.
	_angles += tumble_speed * delta
	_pivot.rotation = _angles
	_pivot.position.y = sin(_t * bob_speed) * bob_height

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
	var clip := _find_clip(anim)
	if clip == &"":
		push_warning("MenuHero: no menu pose found. Clips in the model: %s" % [anim.get_animation_list()])
		return
	anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.play(clip)

## Exact candidates first, then anything with "menu" in its name once
## case/separators are stripped, then the remaining candidates — so a
## "Main Menu" clip beats the idle fallback even though idle is listed.
func _find_clip(anim: AnimationPlayer) -> StringName:
	var first := pose_candidates[0] if not pose_candidates.is_empty() else &""
	if first != &"" and anim.has_animation(first):
		return first
	for clip in anim.get_animation_list():
		if _normalize(clip).contains("menu"):
			return StringName(clip)
	for candidate in pose_candidates:
		if anim.has_animation(candidate):
			return candidate
	return &""

func _normalize(clip_name: String) -> String:
	return clip_name.to_lower().replace("_", "").replace("-", "").replace(" ", "")
