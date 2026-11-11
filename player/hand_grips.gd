@tool
class_name HandGrips
extends Resource
## Where the shield and weapon sit in the hands during combat, tuned visually
## in tools/grip_lab.tscn (open it, change these in the inspector, save) and
## read by GearDisplay. Offsets are metres from the end of the forearm bone,
## along that bone's own axes; rotations are degrees.

@export var shield_offset := Vector3(0.0, -0.05, 0.1)
@export var shield_rotation_deg := Vector3(0.0, 90.0, 0.0)
@export var weapon_offset := Vector3.ZERO
@export var weapon_rotation_deg := Vector3(120.0, 90.0, 0.0)
