@tool
class_name FantasyInterior
extends Node3D
## Dresses a rectangular room (floor at y 0, door on the +Z wall) as a wizard's cottage:
## hearth, bookshelves, potion shelf, round table with crystal ball, cauldron, chest,
## banners, glowing crystals, a chandelier and drifting motes. The pieces come from
## InteriorParts; this node only decides where they go, from the room's size, so a
## differently sized room just needs a different `room_size`.
##
## Runs in the editor too. Parts are children without an owner: visible and lit in the
## scene view, never saved into the scene, so the .tscn stays clean and this script is the
## single place to change the layout.

## Inner floor size (x, z) in metres.
@export var room_size := Vector2(8.0, 8.0)
## Height from the floor to the ceiling's underside.
@export var ceiling_height := 5.0
## Parts to leave out (any of: rug, fireplace, shelves, table, cauldron, chest, banners,
## crystals, chandelier, motes). Handy when the room already has something there.
@export var skip: PackedStringArray = []
## Seed for the book / potion colours.
@export var seed_value := 7

const WALL_GAP := 0.12          ## furniture stands this far off the wall face
const FACE_PLUS_X := PI * 0.5   ## yaw that turns a piece's front (+Z) to +X (standing on the west wall)
const FACE_MINUS_X := -PI * 0.5
const FACE_PLUS_Z := 0.0
const META := &"fantasy_interior"

func _ready() -> void:
	_clear()
	_build()

func _clear() -> void:
	for child in get_children():
		if child.has_meta(META):
			remove_child(child)
			child.queue_free()

func _use(part_name: String) -> bool:
	return not skip.has(part_name)

func _put(part: Node3D, pos: Vector3, yaw := 0.0) -> void:
	part.set_meta(META, true)
	part.position = pos
	part.rotation.y = yaw
	add_child(part)

func _build() -> void:
	var hx := room_size.x * 0.5
	var hz := room_size.y * 0.5
	var west := -hx + WALL_GAP + 0.5     # a piece 1 m deep, backed on the west wall, has its centre here
	var east := hx - WALL_GAP - 0.5
	var back := -hz + WALL_GAP + 0.5     # the wall opposite the door
	if _use("rug"):
		_put(InteriorParts.rug(2.3, Color(0.4, 0.14, 0.2), Color(0.8, 0.62, 0.25)), Vector3(-0.4, 0, 0.6))
	if _use("fireplace"):
		_put(InteriorParts.fireplace(), Vector3(west - 0.1, 0, -0.6), FACE_PLUS_X)
	if _use("shelves"):
		_put(InteriorParts.shelf(2.4, 3.4, InteriorParts.Fill.BOOKS, seed_value), Vector3(-2.7, 0, back - 0.2))
		_put(InteriorParts.shelf(2.4, 3.4, InteriorParts.Fill.BOOKS, seed_value + 1), Vector3(-0.2, 0, back - 0.2))
		_put(InteriorParts.shelf(2.2, 2.9, InteriorParts.Fill.POTIONS, seed_value + 2), Vector3(west - 0.15, 0, 2.2), FACE_PLUS_X)
	if _use("banners"):
		_put(InteriorParts.banner(InteriorParts.VELVET), Vector3(1.4, 1.0, -hz + 0.1))
		_put(InteriorParts.banner(InteriorParts.VELVET_DARK), Vector3(hx - 0.1, 1.0, 0.4), FACE_MINUS_X)
	if _use("table"):
		_put(InteriorParts.table(0.85), Vector3(-0.6, 0, 0.5))
		_put(InteriorParts.stool(), Vector3(-1.9, 0, 0.9), 0.4)
		_put(InteriorParts.stool(), Vector3(0.8, 0, 0.0), -0.6)
	if _use("cauldron"):
		_put(InteriorParts.cauldron(), Vector3(-2.3, 0, 2.3))
	if _use("chest"):
		_put(InteriorParts.chest(), Vector3(east + 0.1, 0, 2.0), FACE_MINUS_X)
	if _use("crystals"):
		_put(InteriorParts.crystals(InteriorParts.CRYSTAL), Vector3(hx - 0.8, 0, hz - 0.9), 0.8)
	if _use("chandelier"):
		_put(InteriorParts.chandelier(1.3), Vector3(-0.6, ceiling_height, 0.5))
	if _use("motes"):
		var motes := InteriorParts.floating_motes(Vector3(hx - 0.5, 1.5, hz - 0.5))
		_put(motes, Vector3(0, 1.8, 0))
