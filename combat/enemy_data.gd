class_name EnemyData
extends Resource
## Data-driven enemy definition. Make new enemies by creating new instances/.tres files.

@export var id: StringName = &"grunt"
@export var display_name := "Grunt"
@export var max_hp := 60.0
@export var xp := 20
@export var move_speed := 3.5
@export var color := Color(0.8, 0.2, 0.2)
@export var size := 1.0
@export var patterns: Array[BulletPattern] = []
