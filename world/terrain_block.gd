@tool
class_name TerrainBlock
extends StaticBody3D
## One resizable terrain chunk: a dirt box with a thin grass cap on top,
## plus the collision shape that covers both — built from a single `size`,
## instead of hand-matching a separate grass MeshInstance3D's dimensions to
## a separate dirt MeshInstance3D's every time a piece of terrain changes
## shape. Drop this script onto any StaticBody3D (or just add a node and
## attach it) and it builds/owns its own Dirt, Grass and Collision children —
## nothing else to wire up by hand.
##
## @tool so it rebuilds live in the editor as size/grass_thickness/materials
## are tweaked in the Inspector, with no need to run the game to preview.
##
## Origin is the BOTTOM CENTER of the dirt box (so placing the node is just
## "put this where the ground should start"), with the grass cap sitting
## directly on top and the collision shape spanning dirt + grass combined.

## Width (x) / dirt height (y) / depth (z). The grass cap adds
## grass_thickness on top of this, it isn't part of `size` itself — so
## resizing a block's footprint or dirt depth never requires touching the
## grass layer separately.
@export var size := Vector3(4.0, 2.0, 4.0):
	set(value):
		size = value
		_rebuild()

@export_range(0.01, 2.0, 0.01) var grass_thickness := 0.3:
	set(value):
		grass_thickness = value
		_rebuild()

@export var grass_material: Material = preload("res://assets/materials/grass.tres"):
	set(value):
		grass_material = value
		_rebuild()

@export var dirt_material: Material = preload("res://assets/materials/dirt.tres"):
	set(value):
		dirt_material = value
		_rebuild()

var _dirt_mesh: MeshInstance3D
var _grass_mesh: MeshInstance3D
var _collision: CollisionShape3D

func _ready() -> void:
	_ensure_children()
	_rebuild()

## Creates the three child nodes once, if they don't already exist (e.g. a
## freshly-attached script, or a scene instance that already has them from a
## previous save). Safe to call repeatedly.
func _ensure_children() -> void:
	_dirt_mesh = get_node_or_null("Dirt") as MeshInstance3D
	if _dirt_mesh == null:
		_dirt_mesh = MeshInstance3D.new()
		_dirt_mesh.name = &"Dirt"
		_dirt_mesh.mesh = BoxMesh.new()
		add_child(_dirt_mesh)
		if Engine.is_editor_hint():
			_dirt_mesh.owner = get_tree().edited_scene_root

	_grass_mesh = get_node_or_null("Grass") as MeshInstance3D
	if _grass_mesh == null:
		_grass_mesh = MeshInstance3D.new()
		_grass_mesh.name = &"Grass"
		_grass_mesh.mesh = BoxMesh.new()
		add_child(_grass_mesh)
		if Engine.is_editor_hint():
			_grass_mesh.owner = get_tree().edited_scene_root

	_collision = get_node_or_null("Collision") as CollisionShape3D
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = &"Collision"
		_collision.shape = BoxShape3D.new()
		add_child(_collision)
		if Engine.is_editor_hint():
			_collision.owner = get_tree().edited_scene_root

func _rebuild() -> void:
	if _dirt_mesh == null:
		return   ## setters can fire before _ready() while the scene is still loading

	(_dirt_mesh.mesh as BoxMesh).size = size
	_dirt_mesh.position = Vector3(0.0, size.y * 0.5, 0.0)
	_dirt_mesh.material_override = dirt_material

	var grass_size := Vector3(size.x, grass_thickness, size.z)
	(_grass_mesh.mesh as BoxMesh).size = grass_size
	_grass_mesh.position = Vector3(0.0, size.y + grass_thickness * 0.5, 0.0)
	_grass_mesh.material_override = grass_material

	var total_height := size.y + grass_thickness
	(_collision.shape as BoxShape3D).size = Vector3(size.x, total_height, size.z)
	_collision.position = Vector3(0.0, total_height * 0.5, 0.0)
