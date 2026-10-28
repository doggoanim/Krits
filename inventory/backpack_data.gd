class_name BackpackData
extends Resource
## A purchasable bag upgrade. Capacity = Inventory.BASE_SLOTS + the best
## backpack owned's `slots` (they replace each other, they don't stack).

@export var id: StringName = &""
@export var display_name := ""
@export var price := 0
@export var slots := 0   ## extra slots on top of the base capacity
