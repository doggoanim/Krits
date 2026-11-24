@tool
class_name NPC
extends Interactable
## A talkable world actor: shows a floating prompt while the player is in
## range and able to talk, and opens DialogueBox on `dialogue` when they
## press interact. Build it like WorldEnemy — give it a CollisionShape3D for
## its physical body (so the player can't walk through it) and whatever
## visual you want (a model, a placeholder mesh) as children; the range/
## prompt/trigger plumbing itself lives in Interactable (see there) — this
## just supplies what "usable" and "interact" mean for a conversation.

## Easiest way to give an NPC lines: a .dlg text file (format: see
## dialogue/dialogue_parser.gd). When set it replaces `dialogue`/`variants`.
@export_file("*.dlg") var dialogue_file: String
@export var dialogue: DialogueNode
## Say something different once a story flag is set; the first variant whose
## flag is set wins, otherwise `dialogue` is used. See DialogueVariant.
@export var variants: Array[DialogueVariant] = []
@export var head_height := 1.6          ## where the camera looks while talking
@export var face_player := true         ## turn toward the player during a conversation
@export var facing_offset := 0.0        ## radians; PI if the model's front is +Z instead of -Z

## Optional rigged model (e.g. assets/npcs/Mayor_Arse.glb). When set it replaces
## the placeholder "Mesh" child, is scaled to `model_height` and loops
## `idle_animation` (empty = the model's first real clip).
@export var model: PackedScene:
	set(v):
		model = v
		_refresh_editor_preview()
@export var model_height := 1.9:
	set(v):
		model_height = v
		_refresh_editor_preview()
@export var idle_animation: StringName = &""
## Optional extra clips for an NPC on a daily routine (NpcSchedule picks the pose; empty = idle).
@export var walk_animation: StringName = &""    ## while strolling between places
@export var sit_animation: StringName = &""     ## resting pose of a stop with rest_pose = SIT
@export var look_animation: StringName = &""    ## resting pose of a stop with rest_pose = LOOK (staring at something)

## What the model is doing, as far as its clips go.
enum Pose { IDLE, WALK, SIT, LOOK }
const POSE_BLEND := 0.2

const EDITOR_PREVIEW_NAME := "EditorModelPreview"

## Talking pop: while this NPC speaks, its model squashes and stretches on every
## word (see talk_pop(), called by DialogueStage). Strength 0 turns it off.
@export_group("Talking")
@export var talk_pop_strength := 1.0
@export var talk_pop_stretch := Vector2(0.97, 1.06)   ## (x/z, y) scale at the top of the pop
@export var talk_pop_squash := Vector2(1.02, 0.98)   ## (x/z, y) scale of the little rebound
@export var talk_pop_min_gap := 0.18                 ## seconds between pops, so a fast word run stays readable
@export_group("")

var _talk_tween: Tween
var _talk_last_msec := -100000
var _talk_rest_scale := Vector3.ONE
var _model_node: Node3D
var _anim: AnimationPlayer
var _pose := -1
var _rest_yaw := 0.0
var _turn_tween: Tween

var _script: DialogueScript   ## parsed from dialogue_file, if any

## False while something (an NpcSchedule sending the NPC indoors) has taken the NPC out of
## the world: it can't be talked to.
var available := true

func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()
		return
	super()
	NpcStomp.attach(self)
	if not dialogue_file.is_empty():
		_script = DialogueParser.load_file(dialogue_file)
	if model != null:
		_build_model()

## Editor only: shows `model` where the NPC stands so the scene reads like the
## game does. The preview node has no owner (never saved into the scene) and
## the placeholder "Mesh" is hidden while it's up, then un-hidden around saves
## so the .tscn itself never changes.
func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var old := get_node_or_null(EDITOR_PREVIEW_NAME)
	if old != null:
		remove_child(old)
		old.queue_free()
	var placeholder := get_node_or_null("Mesh") as Node3D
	if model == null:
		if placeholder != null:
			placeholder.visible = true
		return
	var node := model.instantiate() as Node3D
	if node == null:
		return
	node.name = EDITOR_PREVIEW_NAME
	add_child(node)   # no owner on purpose: not saved
	ModelUtil.fit_height(node, model_height)
	if placeholder != null:
		placeholder.visible = false

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	var placeholder := get_node_or_null("Mesh") as Node3D
	if placeholder == null:
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		placeholder.visible = true
	elif what == NOTIFICATION_EDITOR_POST_SAVE and model != null:
		placeholder.visible = false

## Swaps the placeholder mesh for `model` and starts its idle loop.
func _build_model() -> void:
	var placeholder := get_node_or_null("Mesh")
	if placeholder != null:
		placeholder.queue_free()
	var node := model.instantiate() as Node3D
	if node == null:
		return
	add_child(node)
	_model_node = node
	ModelUtil.fit_height(node, model_height)
	ModelUtil.apply_cel_shading(node, [], {}, Callable(OutlineSystem, &"mark_occludable"))
	var anim := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	SteppedAnimator.attach(anim)
	var clip := idle_animation
	if clip == &"" or not anim.has_animation(clip):
		clip = &""
		for clip_name in anim.get_animation_list():
			if clip_name != &"RESET" and clip_name != &"Nothing":
				clip = clip_name
				break
	_anim = anim
	for extra in [walk_animation, sit_animation, look_animation]:
		_loop_clip(extra)
	if clip != &"":
		idle_animation = clip
		set_pose(Pose.IDLE)

## Loops `clip` if the model has it (a single-frame pose has nothing to loop).
func _loop_clip(clip: StringName) -> void:
	if _anim == null or clip == &"" or not _anim.has_animation(clip):
		return
	var a := _anim.get_animation(clip)
	if a.length > 0.0:
		a.loop_mode = Animation.LOOP_LINEAR

## Switches the model to the clip for `pose` (falls back to the idle clip when the pose has none).
## Safe to call every frame.
func set_pose(pose: Pose) -> void:
	if _anim == null or pose == _pose:
		return
	var clip := idle_animation
	match pose:
		Pose.WALK: clip = walk_animation
		Pose.SIT: clip = sit_animation
		Pose.LOOK: clip = look_animation
	if clip == &"" or not _anim.has_animation(clip):
		clip = idle_animation
	_pose = pose
	_loop_clip(idle_animation)
	if _anim.has_animation(clip):
		_anim.play(clip, POSE_BLEND)

## True when the model has its own walk clip (so the code bob isn't needed).
func has_walk_clip() -> bool:
	return _anim != null and walk_animation != &"" and _anim.has_animation(walk_animation)

## Grounded (not mid-air/rolling/diving/etc.), alive, and nothing else
## already has a conversation open — same spirit as the checks other
## triggered moves make before taking over (e.g. WallClimbState's regrab
## cooldown), just gating a talk instead of a move.
func _can_interact() -> bool:
	return (available and _current_dialogue() != null and player != null and not player.dead
		and player.machine.current_name == &"Ground"
		and DialogueBox.instance != null and not DialogueBox.instance.is_active())

func _interact() -> void:
	DialogueBox.instance.start(_current_dialogue(), self)

func _current_dialogue() -> DialogueNode:
	if _script != null:
		return _script.current()
	for v in variants:
		if v != null and v.dialogue != null and v.required_flag != &"" and Game.flag(v.required_flag):
			return v.dialogue
	return dialogue

# --- DialogueStage speaker interface ------------------------------------

## What squashes and stretches while talking: the model, else the placeholder mesh.
func _talk_target() -> Node3D:
	if _model_node != null and is_instance_valid(_model_node):
		return _model_node
	return get_node_or_null("Mesh") as Node3D

## One squash-and-stretch pop (feet stay planted, since scaling is about the NPC's
## origin): shoots tall and thin, rebounds a bit squat, settles back.
func talk_pop() -> void:
	var target := _talk_target()
	if target == null or talk_pop_strength <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now - _talk_last_msec < int(talk_pop_min_gap * 1000.0):
		return
	_talk_last_msec = now
	if _talk_tween != null and _talk_tween.is_valid():
		_talk_tween.kill()
		target.scale = _talk_rest_scale
	else:
		_talk_rest_scale = target.scale
	var k := talk_pop_strength
	var rest := _talk_rest_scale
	var up := Vector3(lerpf(1.0, talk_pop_stretch.x, k), lerpf(1.0, talk_pop_stretch.y, k), lerpf(1.0, talk_pop_stretch.x, k))
	var down := Vector3(lerpf(1.0, talk_pop_squash.x, k), lerpf(1.0, talk_pop_squash.y, k), lerpf(1.0, talk_pop_squash.x, k))
	_talk_tween = create_tween()
	_talk_tween.tween_property(target, "scale", rest * up, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_talk_tween.tween_property(target, "scale", rest * down, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_talk_tween.tween_property(target, "scale", rest, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## The node that shows the NPC (model, else the placeholder mesh) — what a routine bobs while walking.
func get_visual() -> Node3D:
	return _talk_target()

func get_focus_point() -> Vector3:
	return global_position + Vector3.UP * head_height

func face_toward(world_pos: Vector3) -> void:
	if not face_player:
		return
	var d := world_pos - global_position
	_rest_yaw = rotation.y
	_turn_to(atan2(-d.x, -d.z) + facing_offset)

func restore_facing() -> void:
	if face_player:
		_turn_to(_rest_yaw)

func _turn_to(yaw: float) -> void:
	if _turn_tween:
		_turn_tween.kill()
	_turn_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, yaw), 0.4)
