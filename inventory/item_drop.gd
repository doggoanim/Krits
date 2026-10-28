class_name ItemDrop
extends Resource
## A possible drop on an EnemyData: `chance` (0..1) to give min..max of an item.

@export var item_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var chance := 1.0
@export var min_count := 1
@export var max_count := 1

func roll() -> int:
	if randf() > chance:
		return 0
	return randi_range(min_count, maxi(min_count, max_count))
