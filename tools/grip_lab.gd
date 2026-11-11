@tool
class_name GripLab
extends Node3D
## Editor-only workbench for the in-combat hand grips. Open tools/grip_lab.tscn,
## pick a pose, then change `grips` (shield/weapon offset + rotation) in the
## inspector and watch the sword and shield move on the character live. Save
## the scene (Ctrl+S): the values are stored in player/hand_grips.tres, which
## the game reads. Nothing here runs in the game.

const KRITS := preload("res://assets/player/Krits.glb")
const SWORD := preload("res://assets/equipments/sword_wooden.glb")
const BOW := preload("res://assets/equipments/bow_wooden.glb")
const STAFF := preload("res://assets/equipments/staff_apprentice.glb")
const SHIELD := preload("res://assets/equipments/shield_wooden.glb")
const SWORD_SCALE := 0.3
const SWORD_OFFSET := Vector3(0.0, 0.1, 0.0)
const SWORD_ROT := Vector3(0.0, 0.0, 180.0)
const BOW_SCALE := 0.3
const BOW_OFFSET := Vector3(0.0, -0.3, 0.0)
const STAFF_SCALE := 0.28
const STAFF_OFFSET := Vector3(0.0, -0.315, 0.0)
const SHIELD_SCALE := 0.26
const HEIGHT := 1.8   ## Player.STAND_HEIGHT
const SHIELD_BONE := &"LowerArm.L"
const WEAPON_BONE := &"LowerArm.R"

@export var grips: HandGrips
## Which weapon is shown in the right hand; the grip fields for that weapon are the ones that apply.
@export_enum("sword", "bow", "staff") var weapon := "sword":
	set(v):
		weapon = v
		_show_weapon()
@export_enum("idle", "run", "attack1", "attack2", "attack3", "crouch_idle", "falling", "ground_pound", "ground_pound_land") var pose := "idle":
	set(v):
		pose = v
		_play()

var _krits: Node3D
var _skeleton: Skeleton3D
var _anim: AnimationPlayer
var _shield_grip: Node3D
var _weapon_grip: Node3D

func _ready() -> void:
	_krits = KRITS.instantiate() as Node3D
	add_child(_krits)
	_krits.scale = Vector3.ONE * _fit_scale(_krits, HEIGHT)
	_skeleton = _krits.find_child("Skeleton3D", true, false) as Skeleton3D
	_anim = _krits.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null:
		push_warning("GripLab: no Skeleton3D found in Krits.glb")
		return
	_shield_grip = _make_grip(SHIELD_BONE, SHIELD, SHIELD_SCALE, Vector3.ZERO, Vector3.ZERO)
	_weapon_grip = _make_grip(WEAPON_BONE, SWORD, SWORD_SCALE, SWORD_OFFSET, SWORD_ROT)
	_show_weapon()
	_play()

func _process(_delta: float) -> void:
	if grips == null or _shield_grip == null:
		return
	_shield_grip.position = grips.shield_offset
	_shield_grip.rotation_degrees = grips.shield_rotation_deg
	var g := grips.weapon_grip(["sword", "bow", "staff"].find(weapon))
	_weapon_grip.position = g[0]
	_weapon_grip.rotation_degrees = g[1]

## Swaps the model under the weapon grip for the chosen weapon.
func _show_weapon() -> void:
	if _weapon_grip == null:
		return
	for c in _weapon_grip.get_children():
		c.queue_free()
	var scene := SWORD
	var scl := SWORD_SCALE
	var off := SWORD_OFFSET
	var rot := SWORD_ROT
	if weapon == "bow":
		scene = BOW
		scl = BOW_SCALE
		off = BOW_OFFSET
		rot = Vector3.ZERO
	elif weapon == "staff":
		scene = STAFF
		scl = STAFF_SCALE
		off = STAFF_OFFSET
		rot = Vector3.ZERO
	var item := scene.instantiate() as Node3D
	item.scale = Vector3.ONE * scl
	item.position = off
	item.rotation_degrees = rot
	_weapon_grip.add_child(item)

func _play() -> void:
	if _anim != null and _anim.has_animation(pose):
		_anim.play(pose)
		_anim.get_animation(pose).loop_mode = Animation.LOOP_LINEAR

## Same construction as GearDisplay._make_grip(): attachment on the bone, a
## metre-scaled node at the bone's end, the grip, then the item model.
func _make_grip(bone_name: StringName, model: PackedScene, model_scale: float, model_offset: Vector3, model_rot: Vector3) -> Node3D:
	var idx := _skeleton.find_bone(bone_name)
	if idx < 0:
		push_warning("GripLab: no bone %s" % bone_name)
		return null
	var unit := maxf(_skeleton.global_basis.get_scale().x, 0.0001)
	var att := BoneAttachment3D.new()
	att.bone_name = bone_name
	_skeleton.add_child(att)
	var end := Node3D.new()
	end.scale = Vector3.ONE / unit
	var kids := _skeleton.get_bone_children(idx)
	if not kids.is_empty():
		end.position = Vector3(0.0, _skeleton.get_bone_rest(kids[0]).origin.length(), 0.0)
	att.add_child(end)
	var grip := Node3D.new()
	end.add_child(grip)
	var item := model.instantiate() as Node3D
	item.scale = Vector3.ONE * model_scale
	item.position = model_offset
	item.rotation_degrees = model_rot
	grip.add_child(item)
	return grip

## Same result as ModelUtil.fit_height(), reproduced here so the editor never
## has to call into game scripts.
static func _fit_scale(model: Node3D, target_height: float) -> float:
	var box := _aabb(model, Transform3D.IDENTITY)
	return target_height / box.size.y if box.size.y > 0.001 else 1.0

static func _aabb(n: Node, parent_xform: Transform3D) -> AABB:
	var xform := parent_xform
	if n is Node3D:
		xform = parent_xform * (n as Node3D).transform
	var box := AABB()
	var has := false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		box = xform * (n as MeshInstance3D).mesh.get_aabb()
		has = true
	for c in n.get_children():
		var b := _aabb(c, xform)
		if b.size != Vector3.ZERO:
			box = box.merge(b) if has else b
			has = true
	return box
