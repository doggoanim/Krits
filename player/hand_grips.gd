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

## Placement for a weapon kind (WeaponData.Kind: 0 sword, 1 bow, 2 staff) as
## [offset, rotation_deg].
func weapon_grip(kind: int) -> Array:
	match kind:
		1: return [bow_offset, bow_rotation_deg]
		2: return [staff_offset, staff_rotation_deg]
	return [weapon_offset, weapon_rotation_deg]
