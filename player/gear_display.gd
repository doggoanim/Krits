class_name GearDisplay
extends Node3D
## Shows what the player has equipped as a floating rig behind them:
##
##   Player ──(lagged follow)──> shield anchor (FloatingAnchor)
##                                  ├─ shield model
##                                  └─ weapon pivot (the shield's top edge) ── weapon model (swings)
##
## The shield floats at the player's back; the weapon hangs off the back of
## the shield, so it inherits the shield's lag and adds its own pendulum
## swing. Models, scale, offset and tilt come from EquipmentData
## (model / model_scale / model_offset / model_rotation_deg) — add a .glb to
## an item in EquipmentLibrary and it appears here. Armor is not handled yet.
##
## Rebuilds itself whenever the equipped shield/weapon changes
## (Events.stats_changed). Created by Player (add it after `visual`).

@export var shield_rest := Vector3(0.0, 1.0, 0.2)   ## relative to the player's facing; +Z is behind
@export var shield_default_top := 0.25   ## height of the shield's top edge when there is no shield model
@export var weapon_hang_back := 0.05     ## weapon offset along the anchor's Z, onto the shield's player-facing side (flip the sign if it lands on the wrong face)
@export var staff_mount_drop := 0.315   ## the staff's mount sits this far below the shield's top edge — its centre, so it tilts about the middle
@export var staff_tilt_deg := 22.0   ## how far a floating staff leans toward the player's right
@export var follow_speed := 90.0   ## how tightly the gear tracks the player (higher = less lag)
@export var turn_speed := 20.0     ## same, for turning to match the player's facing
@export_group("Animation Follow")
## How much the shield follows the character's animated torso (crouching,
## rolling, diving, leaning) instead of just the plain capsule position. 0 = off.
@export_range(0.0, 1.0, 0.05) var animation_follow := 1.0
@export var follow_bone: StringName = &"UpperTorso"
@export var tilt_follow := 18.0   ## how quickly the shield eases into the torso's tilt
@export_group("In Combat (held in hand)")
## During a fight the shield is carried on the left forearm and the sword/bow
## in the right hand, riding the animation, instead of floating behind. Offsets
## are set in `grips` (player/hand_grips.tres) — tune them visually with
## tools/grip_lab.tscn.
@export var hold_in_combat := true
@export var shield_hand_bone: StringName = &"LowerArm.L"
@export var weapon_hand_bone: StringName = &"LowerArm.R"
@export var grips: HandGrips = preload("res://player/hand_grips.tres")   ## tuned in tools/grip_lab.tscn
@export_group("Swing")
@export var swing_strength := 0.06     ## radians of weapon swing per m/s of anchor speed
@export var swing_max := 0.7           ## radians
@export var swing_follow := 12.0       ## spring stiffness (higher = snappier)
@export var swing_spring := 4.0        ## damping (higher = settles faster, less wobble)

var _player: Player
var _anchor: FloatingAnchor
var _weapon_pivot: Node3D
var _staff_mount: Node3D   ## where a staff floats: same spot as the weapon pivot, but rigid like the shield (no pendulum swing) and tilted
var _shield_model: Node3D
var _weapon_model: Node3D
var _shield_id: StringName = &"?"
var _weapon_id: StringName = &"?"
## Gear is hidden while the player is in one of these states (it would clip through a tumbling body).
const HIDDEN_IN_STATES: Array[StringName] = [&"Roll"]
var _shield_grip: Node3D   ## where the shield rides in combat (left forearm) — see _build_grips()
var _weapon_grip: Node3D   ## ...and the weapon (right hand)
var _in_hand := false
var _grips_built := false
var _skeleton: Skeleton3D
var _bone := -1
var _tilt := Quaternion.IDENTITY
var _pendulum := PendulumSwing.new()   ## the weapon's swing (see PendulumSwing)

func _ready() -> void:
	_pendulum.strength = swing_strength
	_pendulum.max_angle = swing_max
	_pendulum.follow = swing_follow
	_pendulum.damping = swing_spring
	_player = get_parent() as Player   # created by Player, which must already have its visual
	_anchor = FloatingAnchor.new()
	_anchor.name = "ShieldAnchor"
	_anchor.position_follow = follow_speed
	_anchor.turn_follow = turn_speed
	add_child(_anchor)
	_weapon_pivot = Node3D.new()
	_weapon_pivot.name = "WeaponPivot"
	_anchor.add_child(_weapon_pivot)
	_staff_mount = Node3D.new()
	_staff_mount.name = "StaffMount"
	_staff_mount.rotation_degrees.z = -staff_tilt_deg   # -Z roll leans the top toward +X, the player's right
	_anchor.add_child(_staff_mount)
	_find_bone()
	Events.stats_changed.connect(_refresh)
	_place_weapon_pivot()
	_refresh()
	_anchor.snap_to(_target_position(), _target_yaw())

func _physics_process(delta: float) -> void:
	if _player == null or _player.visual == null:
		return
	var shown := not HIDDEN_IN_STATES.has(_player.machine.current_name)
	visible = shown
	if _shield_grip:
		_shield_grip.visible = shown
	if _weapon_grip:
		_weapon_grip.visible = shown
	_sync_hand_mode()
	if _skeleton == null:
		_find_bone()
	var pose := _bone_pose_delta()
	var want: Quaternion = Quaternion.IDENTITY.slerp(pose[1], animation_follow)
	_tilt = _tilt.slerp(want, 1.0 - exp(-tilt_follow * delta))
	var vel := _anchor.follow(_target_position() + pose[0] * animation_follow, _target_yaw(), delta, Basis(_tilt))
	_update_swing(vel, delta)

# ---------------------------------------------------------------- follow

func _find_bone() -> void:
	var model := _player.visual.get_model() if _player and _player.visual else null
	if model == null:
		return
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null:
		_bone = _skeleton.find_bone(follow_bone)
		if _bone < 0:
			_skeleton = null

## How far the animation has moved/turned the torso from its rest pose, in
## world terms: [Vector3 offset, Quaternion rotation]. Identity when there is
## no skeleton, so the shield just keeps its plain position.
func _bone_pose_delta() -> Array:
	if _skeleton == null or _bone < 0 or not is_instance_valid(_skeleton):
		return [Vector3.ZERO, Quaternion.IDENTITY]
	var pose := _skeleton.get_bone_global_pose(_bone)
	var rest := _skeleton.get_bone_global_rest(_bone)
	var sb := _skeleton.global_basis
	var offset := sb * (pose.origin - rest.origin)
	var local_rot := (pose.basis.orthonormalized() * rest.basis.orthonormalized().inverse())
	var world_rot := sb.orthonormalized() * local_rot * sb.orthonormalized().inverse()
	return [offset, world_rot.get_rotation_quaternion()]

func _target_yaw() -> float:
	return _player.visual.global_rotation.y

func _target_position() -> Vector3:
	var facing_basis := Basis(Vector3.UP, _target_yaw())
	return _player.visual.global_position + facing_basis * shield_rest   # the model, not the collision body

## The weapon is a damped spring: anchor motion (in the anchor's own frame)
## pulls it off-centre, so it trails when you run, kicks when you stop, and
## settles back.
func _update_swing(world_vel: Vector3, delta: float) -> void:
	var swing := _pendulum.step(_anchor.global_basis.inverse() * world_vel, delta)
	_weapon_pivot.rotation = Vector3(swing.x, 0.0, swing.y)

# ---------------------------------------------------------------- equipment

func _refresh() -> void:
	var stats := Game.stats
	var shield := stats.equipped_shield
	var weapon := stats.equipped_weapon
	var shield_id := shield.id if shield else &""
	var weapon_id := weapon.id if weapon else &""
	if shield_id != _shield_id:
		_shield_id = shield_id
		_shield_model = _swap(_shield_model, _anchor, shield)
		_place_weapon_pivot()
	if weapon_id != _weapon_id:
		_weapon_id = weapon_id
		# Swords/bows hang and swing from the shield; a staff floats rigidly beside it.
		var staff := weapon != null and weapon.kind == WeaponData.Kind.STAFF
		_weapon_model = _swap(_weapon_model, _staff_mount if staff else _weapon_pivot, weapon)
	_place_models()

# ---------------------------------------------------------------- in hand

func _sync_hand_mode() -> void:
	var want := hold_in_combat and Game.in_combat and _skeleton != null
	if want and not _grips_built:
		_grips_built = true
		_build_grips()
	if want != _in_hand:
		_in_hand = want
		_place_models()

## Moves the worn models between their floating spots and the hand grips.
func _place_models() -> void:
	var shield_parent: Node3D = _shield_grip if _in_hand and _shield_grip else _anchor
	_reparent(_shield_model, shield_parent)
	var weapon := Game.stats.equipped_weapon
	var staff := weapon != null and weapon.kind == WeaponData.Kind.STAFF
	var weapon_parent: Node3D = _weapon_grip if _in_hand and _weapon_grip else (_staff_mount if staff else _weapon_pivot)
	if _in_hand and _weapon_grip and weapon != null:
		var g := grips.weapon_grip(weapon.kind)   # each kind of weapon is held differently
		_weapon_grip.position = g[0]
		_weapon_grip.rotation_degrees = g[1]
	_reparent(_weapon_model, weapon_parent)

func _reparent(model: Node3D, parent: Node3D) -> void:
	if model != null and is_instance_valid(model) and model.get_parent() != parent:
		model.reparent(parent, false)

## One BoneAttachment3D per hand, with a metre-scaled grip node at the end of
## the bone (the skeleton is scaled to fit the character, so grips undo that).
func _build_grips() -> void:
	_shield_grip = _make_grip(shield_hand_bone, grips.shield_offset, grips.shield_rotation_deg)
	_weapon_grip = _make_grip(weapon_hand_bone, grips.weapon_offset, grips.weapon_rotation_deg)

func _make_grip(bone_name: StringName, offset: Vector3, rotation_deg: Vector3) -> Node3D:
	var idx := _skeleton.find_bone(bone_name)
	if idx < 0:
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
	else:
		end.position = Vector3.ZERO
	att.add_child(end)
	var grip := Node3D.new()
	grip.position = offset
	grip.rotation_degrees = rotation_deg
	end.add_child(grip)
	return grip

## Frees `old`, instances `item`'s model under `parent` (if it has one) with
## the item's scale/offset/tilt applied, and returns it (or null).
func _swap(old: Node3D, parent: Node3D, item: EquipmentData) -> Node3D:
	if old and is_instance_valid(old):
		old.queue_free()
	if item == null or item.model == null:
		return null
	var node := item.model.instantiate() as Node3D
	if node == null:
		return null
	node.scale = Vector3.ONE * item.model_scale
	node.position = item.model_offset
	node.rotation_degrees = item.model_rotation_deg
	parent.add_child(node)
	# Same treatment as the character: cel shading + the shared outline pass,
	# and a halftone x-ray copy so it shows through walls with the player.
	ModelUtil.apply_cel_shading(node, [], {}, Callable(OutlineSystem, &"mark"))
	_register_xray.call_deferred(node)   # the player's PlayerXray may not exist yet
	return node

func _register_xray(model: Node3D) -> void:
	if is_instance_valid(model) and _player and _player.xray:
		_player.xray.attach(model)

## The weapon hangs from the top edge of the shield, just behind its face.
func _place_weapon_pivot() -> void:
	var top := shield_default_top
	if _shield_model and is_instance_valid(_shield_model):
		top = _top_edge(_shield_model)
	_weapon_pivot.position = Vector3(0.0, top, weapon_hang_back)
	_staff_mount.position = _weapon_pivot.position - Vector3(0.0, staff_mount_drop, 0.0)

## Highest point of a model's meshes, in the anchor's space.
func _top_edge(model: Node3D) -> float:
	var top := -INF
	var to_anchor := _anchor.global_transform.affine_inverse()
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box := (to_anchor * mi.global_transform) * mi.get_aabb()
		top = maxf(top, box.end.y)
	return top if top > -INF else shield_default_top
