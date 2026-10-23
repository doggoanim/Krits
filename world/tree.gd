@tool
extends Node3D
## Editor-time template for hand-placed trees.
##
## Drag a Tree instance anywhere in the world, then pick which trunk/leaves
## mesh it uses from the dropdowns in the Inspector, and assign a Trunk
## Material / Leaves Material if you want to recolor. Nothing here is
## random or runtime-generated: the variant and material you pick are
## baked into the scene file like any other node property, and switching
## variants keeps reapplying whatever material you've assigned.

const TRUNK_PATH_FORMAT := "res://assets/world/trunk_%d.glb"
const LEAVES_PATH_FORMAT := "res://assets/world/leaves_%d.glb"
const TRUNK_VARIANT_COUNT := 4
const LEAVES_VARIANT_COUNT := 3

@export_range(1, TRUNK_VARIANT_COUNT, 1) var trunk_variant: int = 1:
	set(value):
		trunk_variant = value
		_refresh_slot(&"TrunkSlot", TRUNK_PATH_FORMAT % trunk_variant, trunk_material)

@export_range(1, LEAVES_VARIANT_COUNT, 1) var leaves_variant: int = 1:
	set(value):
		leaves_variant = value
		_refresh_slot(&"LeavesSlot", LEAVES_PATH_FORMAT % leaves_variant, leaves_material)

@export var trunk_material: Material:
	set(value):
		trunk_material = value
		_apply_material(&"TrunkSlot", trunk_material)

@export var leaves_material: Material:
	set(value):
		leaves_material = value
		_apply_material(&"LeavesSlot", leaves_material)


func _ready() -> void:
	_refresh_slot(&"TrunkSlot", TRUNK_PATH_FORMAT % trunk_variant, trunk_material)
	_refresh_slot(&"LeavesSlot", LEAVES_PATH_FORMAT % leaves_variant, leaves_material)


func _refresh_slot(slot_name: StringName, mesh_path: String, material: Material) -> void:
	if not is_inside_tree():
		return
	var slot := get_node_or_null(NodePath(slot_name)) as Node3D
	if slot == null:
		return
	for child in slot.get_children():
		slot.remove_child(child)
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
			_own_recursive(instance, edited_root)
	_apply_material(slot_name, material)


func _own_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_own_recursive(child, owner)


func _apply_material(slot_name: StringName, material: Material) -> void:
	if material == null or not is_inside_tree():
		return
	var slot := get_node_or_null(NodePath(slot_name)) as Node3D
	if slot == null:
		return
	var mesh_instance := _find_mesh_instance(slot)
	if mesh_instance:
		mesh_instance.material_override = material


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null
