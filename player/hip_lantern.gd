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
const ACTION := &"lantern_toggle"   ## rebindable in Settings > Controls (InputSetup.BINDINGS)

const HINT_ID := &"lantern"   ## the key plate shown until the first toggle (see KeyHints)

const LIT_FLAG := &"lantern_lit"   ## remembered in the save; absent = switched off, as when first picked up

var _lit := false   ## switched on: the light and flame show

## Where the handle sits when standing, relative to the player's facing (-X is
## the left, +Z is behind) — the lantern keeps this spot relative to the hip
## bone, so it rides the animation (rolls, crouches, jumps) from there.
@export var hip_offset := Vector3(-0.22, 0.70, 0.0)
## The skeleton bone it is hooked to: the first whose name contains this
## (lower-cased). The hips, so it follows the body, not a swinging leg.
@export var bone_hint := "lowertorso"
@export var model_height := 0.34            ## metres, handle top to base
@export var glow_color := Color("F3EECA")
@export var light_energy := 1.2
@export var light_range := 7.0
@export var flicker_amount := 0.08          ## fraction of light_energy the flame wavers by (0 = steady)
@export var flicker_speed := 7.0
@export var glow_mesh_name := "Lantern_glow"   ## the glb's inner flame mesh, drawn unshaded in glow_color

@export_group("Swing")
@export var swing_strength := 0.06
@export var swing_max := 0.7
@export var swing_follow := 12.0
@export var swing_spring := 4.0

var _player: Player
var _pivot: Node3D          ## the handle's top — swings
var _glow: MeshInstance3D   ## the flame mesh, hidden while switched off
var _light: OmniLight3D
var _pendulum := PendulumSwing.new()
var _last_pos := Vector3.ZERO
var _skeleton: Skeleton3D
var _bone := -1
var _bone_local := Vector3.ZERO   ## the handle's position in the hip bone's own space

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
	_lit = bool(Game.flag(LIT_FLAG, false))
	_apply_lit()
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
		_glow = glow
		node.add_child(glow)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = glow_color
		glow.material_override = mat
	_register_xray.call_deferred(node)

func _register_xray(model: Node3D) -> void:
	if is_instance_valid(model) and _player and _player.xray:
		_player.xray.attach(model)

## The world position of the handle: `hip_offset` fixed to the hip bone (so it
## follows the animation), or just `hip_offset` if there is no bone.
func _hook_position(yaw: float) -> Vector3:
	var rest_world := _player.visual.global_position + Basis(Vector3.UP, yaw) * hip_offset
	if _skeleton == null:
		_find_bone(rest_world)
	if _skeleton != null and _bone >= 0:
		return (_skeleton.global_transform * _skeleton.get_bone_global_pose(_bone)) * _bone_local
	return rest_world

## Finds the hip bone and records where the handle sits in its local space
## (measured from the rest pose, right now, at the standing offset).
func _find_bone(rest_world: Vector3) -> void:
	var model := _player.visual.get_model()
	if model == null:
		return
	for n in model.find_children("*", "Skeleton3D", true, false):
		var skel := n as Skeleton3D
		for i in skel.get_bone_count():
			if bone_hint in skel.get_bone_name(i).to_lower():
				_skeleton = skel
				_bone = i
				var rest := skel.global_transform * skel.get_bone_global_rest(i)
				_bone_local = rest.affine_inverse() * rest_world
				return

func _process(delta: float) -> void:
	if _player == null or _player.visual == null:
		return
	delta = minf(delta, 1.0 / 30.0)   # keep the spring stable on a frame hitch
	var owned := Game.inventory != null and Game.inventory.has(ITEM_ID)
	if visible != owned:
		visible = owned
		_last_pos = Vector3.ZERO   # no swing kick from the jump back into place
		if owned:   # KeyHints skips it if they already know the key
			var none: Array[StringName] = []
			Events.key_hint_requested.emit(HINT_ID, ACTION, none)
	if not owned:
		return
	if Input.is_action_just_pressed(ACTION) and not Game.input_locked \
			and not (DialogueBox.instance != null and DialogueBox.instance.is_active()) \
			and not get_tree().paused:
		_lit = not _lit
		Game.set_flag(LIT_FLAG, _lit)
		_apply_lit()
		if _player.audio != null:
			_player.audio.play_lantern(_lit)
		Events.key_hint_dismissed.emit(HINT_ID)
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
	if _lit and flicker_amount > 0.0:   # a flame wavers a little; two sines so it never settles into a pattern
		var t := Time.get_ticks_msec() / 1000.0 * flicker_speed
		var f := sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.4
		_light.light_energy = light_energy * (1.0 + f * flicker_amount)

## Switched off, the whole lantern disappears (model, flame and light). The
## x-ray silhouette copies follow their source meshes' visibility (see
## PlayerXray), so they vanish with it.
func _apply_lit() -> void:
	if _pivot != null:
		_pivot.visible = _lit
	if _light != null:
		_light.visible = _lit
	if _glow != null:
		_glow.visible = _lit
