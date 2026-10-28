class_name AbilityData
extends Resource
## An ability the player can learn and put on hotbar slots 1-3. Built by
## AbilityLibrary; `id` is what gets saved. What it actually does when
## triggered lives in AbilityRunner, switched on `effect`.

enum Effect { HEAL, GUARD, SUPER_JUMP, SHOCKWAVE }

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var effect: Effect = Effect.HEAL
@export var cooldown := 10.0       ## seconds before it can be used again
@export var price := 0             ## 0 = not sold in shops
@export var amount := 0.0          ## heal HP / damage multiplier / jump velocity, per effect
@export var duration := 0.0        ## guard time
@export var radius := 0.0          ## shockwave reach
@export var icon: Texture2D        ## optional; slots fall back to a coloured initial
@export var color := Color(0.8, 0.8, 0.8)
