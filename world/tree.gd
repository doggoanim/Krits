@tool
extends Node3D
## Editor-time template for hand-placed trees.
##
## Drag a Tree instance anywhere in the world, then pick which trunk/leaves
## mesh it uses from the dropdowns in the Inspector. Nothing here is random
## or runtime-generated: the variant you pick is baked into the scene file
## exactly like any other node property, the same as if you'd swapped the
## instanced .glb by hand.

const TRUNK_PATH_FORMAT := "res://assets/world/trunk_%d.glb"
const LEAVES_PATH_FORMAT := "res://assets/world/leaves_%d.glb"
const TRUNK_VARIANT_COUNT := 4
const LEAVES_VARIANT_COUNT := 3

@export_range(1, TRUNK_VARIANT_COUNT, 1) var trunk_variant: int = 1:
	set(value):
		trunk_variant = value
		_refresh_slot(&"TrunkSlot", TRUNK_PATH_FORMAT % trunk_variant)

@export_range(1, LEAVES_VARIANT_COUNT, 1) var leaves_variant: int = 1:
	set(value):
		leaves_variant = value
		_refresh_slot(&"LeavesSlot", LEAVES_PATH_FORMAT % leaves_variant)


func _ready() -> void:
	_refresh_slot(&"TrunkSlot", TRUNK_PATH_FORMAT % trunk_variant)
	_refresh_slot(&"LeavesSlot", LEAVES_PATH_FORMAT % leaves_variant)


func _refresh_slot(slot_name: StringName, mesh_path: String) -> void:
	if not is_inside_tree():
		return
	var slot := get_node_or_null(NodePath(slot_name)) as Node3D
	if slot == null:
		return
	for child in slot.get_children():
		child.queue_free()
	if not ResourceLoader.exists(mesh_path):
		push_warning("Tree: no mesh variant at %s" % mesh_path)
		return
	var packed: PackedScene = load(mesh_path)
	var instance := packed.instantiate()
	slot.add_child(instance)
	if Engine.is_editor_hint():
		var edited_root := get_tree().edited_scene_root
		if edited_root:
			instance.owner = edited_root
