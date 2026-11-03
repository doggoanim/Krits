class_name HipLantern
extends Node3D
## The lantern hanging off the player's left hip once they own one (the
## "lantern" key item). It swings with the same PendulumSwing physics as the
## sword, but hangs straight off the body — no floating lag — and glows
## `glow_color`, lighting up the dark around the player with a small OmniLight3D.
## Created by Player (after `visual` and `gear`).

const MODEL: PackedScene = preload("res://assets/equipments/lantern.glb")
const ITEM_ID := &"lantern"

@export var hip_offset := Vector3(-0.42, 0.9, 0.05)   ## relative to the player's facing; -X is the left, +Z is behind
@export var model_height := 0.34            ## metres, handle top to base
@export var glow_color := Color("F3EECA")
@export var light_energy := 1.6
@export var light_range := 7.0
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

func _physics_process(delta: float) -> void:
	if _player == null or _player.visual == null:
		return
	var owned := Game.inventory != null and Game.inventory.has(ITEM_ID)
	if visible != owned:
		visible = owned
		_last_pos = Vector3.ZERO   # no swing kick from the jump back into place
	if not owned:
		return
	var yaw := _player.visual.global_rotation.y
	var facing := Basis(Vector3.UP, yaw)
	var target := _player.visual.global_position + facing * hip_offset
	var velocity := (target - _last_pos) / maxf(delta, 0.0001) if _last_pos != Vector3.ZERO else Vector3.ZERO
	_last_pos = target
	global_position = target
	global_rotation = Vector3(0.0, yaw, 0.0)
	var swing := _pendulum.step(global_basis.inverse() * velocity, delta)
	_pivot.rotation = Vector3(swing.x, 0.0, swing.y)
