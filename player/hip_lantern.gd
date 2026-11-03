class_name HipLantern
extends Node3D
## The lantern hanging off the player's left hip once they own one (the
## "lantern" key item). It swings with the same PendulumSwing physics as the
## sword, but its hook rides the player's left hip bone — so it follows the
## animation, no floating lag — and glows
## `glow_color`, lighting up the dark around the player with a small OmniLight3D.
## Created by Player (after `visual` and `gear`).

const MODEL: PackedScene = preload("res://assets/equipments/lantern.glb")
const ITEM_ID := &"lantern"

## The lantern's hook follows this bone of the player's skeleton, so it moves
## with the animation (rolls, crouches, jumps). Matched loosely: the first bone
## whose name contains "upperleg" and ends in ".L"/"_L".
@export var bone_hint := "upperleg"
@export var side_push := 0.16      ## metres outward from the body's centre, so it hangs beside the hip, not inside it
@export var hang_drop := 0.12      ## metres below the hip joint where the handle sits — raise to hang higher
@export var hip_offset := Vector3(-0.42, 0.7, 0.05)   ## fallback if the skeleton/bone can't be found: relative to the player's facing; -X is the left, +Z is behind
@export var model_height := 0.34            ## metres, handle top to base
@export var glow_color := Color("F3EECA")
@export var light_energy := 0.8
@export var light_range := 3.5
@export var glow_mesh_name := "Lantern_glow"   ## the glb's inner flame mesh, drawn unshaded in glow_color

@export_group("Swing")
@export var swing_strength := 0.06
@export var swing_max := 0.7
@export var swing_follow := 12.0
@export var swing_spring := 4.0

var _player: Player
var _pivot: Node3D          ## the handle's top — swings
var _light: OmniLight3D
var _pendulum := PendulumSwing.new()
var _last_pos := Vector3.ZERO
var _skeleton: Skeleton3D
var _bone := -1

func _ready() -> void:
	top_level = true   # world-space: placed by script each physics frame
	_player = get_parent() as Player
	_pendulum.strength = swing_strength
	_pendulum.max_angle = swing_max
	_pendulum.follow = swing_follow
	_pendulum.damping = swing_spring
	_pivot = Node3D.new()
	_pivot.name = "LanternPivot"
	add_child(_pivot)
	_build_model()
	_light = OmniLight3D.new()
	_light.light_color = glow_color
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, -model_height * 0.5, 0.0)   # inside the lantern
	_pivot.add_child(_light)
	visible = false

## Instances the glb hanging from the pivot: scaled to `model_height`, cel
## shaded like the rest of the gear, with the flame mesh left unshaded.
func _build_model() -> void:
	var node := MODEL.instantiate() as Node3D
	if node == null:
		return
	var glow := node.find_child(glow_mesh_name, true, false) as MeshInstance3D
	if glow != null:
		glow.get_parent().remove_child(glow)   # keep it out of cel shading / outline
	_pivot.add_child(node)
	ModelUtil.fit_height(node, model_height)   # sits on y = 0..height
	node.position.y -= model_height            # so the top (handle) is at the pivot
	ModelUtil.apply_cel_shading(node, [], {}, Callable(OutlineSystem, &"mark"))
	if glow != null:
		node.add_child(glow)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = glow_color
		glow.material_override = mat
	_register_xray.call_deferred(node)

func _register_xray(model: Node3D) -> void:
	if is_instance_valid(model) and _player and _player.xray:
		_player.xray.attach(model)

## The world position of the handle: the left hip bone (animated), pushed out
## to the side and dropped a little; the fixed `hip_offset` if there's no bone.
func _hook_position(yaw: float) -> Vector3:
	if _skeleton == null:
		_find_bone()
	if _skeleton != null and _bone >= 0:
		var joint := (_skeleton.global_transform * _skeleton.get_bone_global_pose(_bone)).origin
		var outward := joint - _player.visual.global_position
		outward.y = 0.0
		outward = outward.normalized() if outward.length() > 0.01 else Vector3.ZERO
		return joint + outward * side_push + Vector3.DOWN * hang_drop
	return _player.visual.global_position + Basis(Vector3.UP, yaw) * hip_offset

func _find_bone() -> void:
	var model := _player.visual.get_model()
	if model == null:
		return
	for n in model.find_children("*", "Skeleton3D", true, false):
		var skel := n as Skeleton3D
		for i in skel.get_bone_count():
			var bone_name := skel.get_bone_name(i).to_lower()
			if bone_hint in bone_name and (bone_name.ends_with(".l") or bone_name.ends_with("_l")):
				_skeleton = skel
				_bone = i
				return

func _process(delta: float) -> void:
	if _player == null or _player.visual == null:
		return
	delta = minf(delta, 1.0 / 30.0)   # keep the spring stable on a frame hitch
	var owned := Game.inventory != null and Game.inventory.has(ITEM_ID)
	if visible != owned:
		visible = owned
		_last_pos = Vector3.ZERO   # no swing kick from the jump back into place
	if not owned:
		return
	var yaw := _player.visual.global_rotation.y
	var target := _hook_position(yaw)
	var velocity := Vector3.ZERO
	if _last_pos != Vector3.ZERO:
		velocity = (target - _last_pos) / maxf(delta, 0.0001)
	_last_pos = target
	global_position = target
	global_rotation = Vector3(0.0, yaw, 0.0)
	var swing := _pendulum.step(global_basis.inverse() * velocity, delta)
	_pivot.rotation = Vector3(swing.x, 0.0, swing.y)
