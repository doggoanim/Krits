class_name EnemyData
extends Resource
## Data-driven enemy definition. Make new enemies by creating new instances/.tres files.

@export var id: StringName = &"grunt"
@export var display_name := "Grunt"
@export var max_hp := 60.0
@export var gold := 20
@export var move_speed := 3.5
## Used for the placeholder sphere when no model is set, and also as the
## accent color for this enemy's slime trail / special-attack projectiles
## when those are enabled below (so one field covers both looks).
@export var color := Color(0.8, 0.2, 0.2)
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

## A telegraphed pounce: holds anim_leap_ready for leap_ready_time, then arcs
## toward wherever the player was standing when the leap committed (not a
## homing target — it's meant to be dodgeable), tumbling as it travels, and
## lands in a damaging burst that also drops a (bigger) puddle if
## leaves_puddle_trail is on. Leave leap_max_cooldown at 0 (the default) to
## skip this attack entirely — most enemies don't have one.
@export_group("Leap Attack")
@export var leap_min_cooldown := 0.0
@export var leap_max_cooldown := 0.0
@export var leap_ready_time := 1.0
@export var leap_travel_time := 0.6    ## seconds spent airborne, regardless of distance
@export var leap_height := 3.0         ## arc apex above a straight line to the landing spot
@export var leap_damage := 14.0
@export var leap_radius := 2.0         ## landing impact radius that can hit the player
@export var anim_leap_ready: StringName = &""
@export var anim_leap: StringName = &""

func has_leap() -> bool:
	return leap_max_cooldown > 0.0

## A machine-gun-style volley: fires a randomized number of aimed shots
## (shoot_count_min..shoot_count_max), playing anim_shoot once per shot.
## Leave shoot_max_cooldown at 0 (the default) to skip this attack.
@export_group("Burst Shoot")
@export var shoot_min_cooldown := 0.0
@export var shoot_max_cooldown := 0.0
@export var shoot_count_min := 1
@export var shoot_count_max := 10
@export var shoot_interval := 0.12     ## time between shots within one burst
@export var shoot_speed := 10.0
@export var shoot_damage := 6.0
@export var anim_shoot: StringName = &""

func has_burst_shoot() -> bool:
	return shoot_max_cooldown > 0.0

## Leaves a damaging, slowing, jump-disabling puddle (see SlimePuddle)
## wherever this enemy walks, plus a bigger one wherever a leap lands.
@export_group("Slime Trail")
@export var leaves_puddle_trail := false
@export var puddle_interval := 0.5     ## seconds between trail puddles while moving
@export var puddle_radius := 1.3
@export var puddle_lifetime := 5.0
@export var puddle_damage := 4.0
@export var puddle_tick_interval := 0.9
@export var puddle_landing_radius_mult := 1.6   ## leap-landing puddles are bigger than trail ones
