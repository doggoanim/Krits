class_name EnemyData
extends Resource
## Data-driven enemy definition. Make new enemies by creating new instances/.tres files.

@export var id: StringName = &"grunt"
@export var display_name := "Grunt"
@export var max_hp := 60.0
@export var xp := 20
@export var move_speed := 3.5
@export var color := Color(0.8, 0.2, 0.2)   ## used for the placeholder sphere when no model is set
@export var size := 1.0
@export var patterns: Array[BulletPattern] = []

## Optional animated model (see EnemyVisual). Leave unset to keep the plain
## procedural sphere — existing enemies (Spinner, Piercer, ...) don't need
## any of this unless/until they get their own model.
@export_group("Model")
@export var model: PackedScene
@export var model_height := 1.4      ## target world-space height when a model is set
## Blender's glTF export doesn't always agree with Godot's -Z-forward
## convention, so an enemy can end up visually facing backward relative to
## its movement direction — same issue PlayerVisual had, same fix: a
## 180-degree turn. Set to 0.0 if a particular model's export already faces -Z.
@export var model_facing_offset := PI
@export var anim_idle: StringName = &"Idle"
@export var anim_move: StringName = &"Moving"
@export var anim_death: StringName = &"Death"
