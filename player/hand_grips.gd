@tool
class_name HandGrips
extends Resource
## Where the shield and weapon sit in the hands during combat, tuned visually
## in tools/grip_lab.tscn (open it, change these in the inspector, save) and
## read by GearDisplay. Offsets are metres from the end of the forearm bone,
## along that bone's own axes; rotations are degrees.

@export var shield_offset := Vector3(0.0, -0.05, 0.1)
@export var shield_rotation_deg := Vector3(0.0, 90.0, 0.0)
@export var weapon_offset := Vector3.ZERO           ## the sword (kept under its old name so saved values still apply)
@export var weapon_rotation_deg := Vector3(120.0, 90.0, 0.0)
@export var bow_offset := Vector3.ZERO
@export var bow_rotation_deg := Vector3(120.0, 90.0, 0.0)
@export var staff_offset := Vector3.ZERO
@export var staff_rotation_deg := Vector3(120.0, 90.0, 0.0)

@export var rod_offset := Vector3(0.055, 0.185, 0.265)       ## the fishing rod (FishingRod); starts out as the staff's grip, tune from there
@export var rod_rotation_deg := Vector3(0, -68.37, -102.275)
@export var rod_scale := 0.4                                   ## the rod glb is ~5.5 units long: this brings it to ~2 m

## A node riding `bone_name` of `skeleton`, at the end of the bone and shifted by
## `offset` / `rotation_deg`: put an item under it and it follows the animation.
## The skeleton is scaled to fit the character, so a metre-scaled node undoes that.
static func make_grip(skeleton: Skeleton3D, bone_name: StringName, offset: Vector3, rotation_deg: Vector3) -> Node3D:
	var idx := skeleton.find_bone(bone_name)
	if idx < 0:
		return null
	var unit := maxf(skeleton.global_basis.get_scale().x, 0.0001)
	var att := BoneAttachment3D.new()
	att.bone_name = bone_name
	skeleton.add_child(att)
	var end := Node3D.new()
	end.scale = Vector3.ONE / unit
	var kids := skeleton.get_bone_children(idx)
	if not kids.is_empty():
		end.position = Vector3(0.0, skeleton.get_bone_rest(kids[0]).origin.length(), 0.0)
	else:
		end.position = Vector3.ZERO
	att.add_child(end)
	var grip := Node3D.new()
	grip.position = offset
	grip.rotation_degrees = rotation_deg
	end.add_child(grip)
	return grip

## Placement for a weapon kind (WeaponData.Kind: 0 sword, 1 bow, 2 staff) as
## [offset, rotation_deg].
func weapon_grip(kind: int) -> Array:
	match kind:
		1: return [bow_offset, bow_rotation_deg]
		2: return [staff_offset, staff_rotation_deg]
	return [weapon_offset, weapon_rotation_deg]
