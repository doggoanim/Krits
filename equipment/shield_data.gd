class_name ShieldData
extends EquipmentData
## Shield slot — raises max shield. See PlayerStats.max_shield().
## Named ShieldData (not just "Shield") to avoid colliding with
## PlayerStats.shield, the current live shield value.

@export var shield_bonus := 0.0
