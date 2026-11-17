@tool
class_name FantasyInterior
extends Node3D
## Dresses a rectangular room (floor at y 0, door on the +Z wall) as a cosy fantasy home:
## hearth with a stew pot, bookshelves, a pantry shelf, a dining table, wardrobe,
## a window, pictures, a plant, a candle ring and drifting dust motes. The pieces come from
## InteriorParts; this node only decides where they go, from the room's size, so a
## differently sized room just needs a different `room_size`.
##
## Runs in the editor too. Parts are children without an owner: visible and lit in the
## scene view, never saved into the scene, so the .tscn stays clean and this script is the
## single place to change the layout.

## HOME: the player's cosy cottage. HALL: the mayor's study (a smaller, grander room).
enum Layout { HOME, HALL }
@export var layout := Layout.HOME
## Inner floor size (x, z) in metres.
@export var room_size := Vector2(8.0, 8.0)
## Height from the floor to the ceiling's underside.
@export var ceiling_height := 5.0
## Parts to leave out (any of: rug, fireplace, shelves, table, wardrobe, decor,
## plant, chandelier, motes). Handy when the room already has something there.
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
	match layout:
		Layout.HALL:
			_build_hall()
		_:
			_build_home()

## The mayor's study: shelves down both side walls, banners and a shield behind the
## desk, candelabras by the door, a carpet runner, a window and a chandelier. The room's
## centre is this node's origin; the desk, chair and mayor are placed in the scene itself.
func _build_hall() -> void:
	var hx := room_size.x * 0.5
	var hz := room_size.y * 0.5
	var run := room_size.y - 0.8
	if _use("rug"):
		_put(InteriorParts.runner(1.5, run, Color(0.4, 0.14, 0.2), Color(0.8, 0.62, 0.25)), Vector3(0, 0, 0.1))
	if _use("decor"):
		_put(InteriorParts.shield(), Vector3(0, 3.4, -hz + 0.1))
		_put(InteriorParts.banner(InteriorParts.ROOF_RED), Vector3(-1.15, 1.0, -hz + 0.1))
		_put(InteriorParts.banner(InteriorParts.ROOF_RED), Vector3(1.15, 1.0, -hz + 0.1))
	# Down the long side walls, from the study at the far end towards the door, a repeating
	# rhythm: shelves, then banner + window, then shelves... so the hall reads like the street.
	var z := -hz + 1.2
	var step := 0
	while z < hz - 2.4:
		for side in [-1.0, 1.0]:
			var wall_x: float = side * (hx - 0.06)
			var yaw := FACE_PLUS_X if side < 0.0 else FACE_MINUS_X
			match step % 3:
				0:
					if _use("shelves"):
						_put(InteriorParts.shelf(1.6, 3.4, InteriorParts.Fill.BOOKS, seed_value + step * 2 + (1 if side > 0.0 else 0)),
							Vector3(side * (hx - 0.4), 0, z), yaw)
				1:
					if _use("decor"):
						_put(InteriorParts.banner(InteriorParts.ROOF_RED), Vector3(wall_x, 1.0, z - 0.9), yaw)
						_put(InteriorParts.window(1.0, 1.6), Vector3(wall_x, 2.6, z + 0.5), yaw)
				_:
					if _use("shelves"):
						_put(InteriorParts.shelf(1.5, 2.6, InteriorParts.Fill.JARS, seed_value + step), Vector3(side * (hx - 0.4), 0, z), yaw)
					if _use("plant") and side < 0.0:
						_put(InteriorParts.plant(), Vector3(-hx + 0.55, 0, z + 1.2))
		z += 2.4
		step += 1
	if _use("candelabra"):
		_put(InteriorParts.candelabra(), Vector3(-hx + 0.5, 0, hz - 0.5))
		_put(InteriorParts.candelabra(), Vector3(hx - 0.5, 0, hz - 0.5))
	if _use("chandelier"):
		var count := maxi(1, roundi(room_size.y / 4.0))
		for i in count:
			_put(InteriorParts.chandelier(1.2), Vector3(0, ceiling_height, lerpf(-hz, hz, (i + 0.5) / count)))
	if _use("motes"):
		_put(InteriorParts.floating_motes(Vector3(hx - 0.4, 1.5, hz - 0.4)), Vector3(0, 1.8, 0))

func _build_home() -> void:
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
		_put(InteriorParts.shelf(2.2, 2.9, InteriorParts.Fill.JARS, seed_value + 2), Vector3(west - 0.15, 0, 2.2), FACE_PLUS_X)
	if _use("decor"):
		_put(InteriorParts.window(1.5, 1.7), Vector3(hx - 0.06, 2.5, -2.7), FACE_MINUS_X)   # on the east wall, beside the bed
		_put(InteriorParts.picture(1.0, 0.75, Color(0.4, 0.6, 0.35)), Vector3(hx - 0.06, 2.6, -0.2), FACE_MINUS_X)
		_put(InteriorParts.picture(0.7, 0.9, Color(0.7, 0.5, 0.3)), Vector3(hx - 0.06, 2.4, 0.8), FACE_MINUS_X)
	if _use("table"):
		_put(InteriorParts.table(0.85), Vector3(-0.6, 0, 0.5))
		_put(InteriorParts.stool(), Vector3(-1.9, 0, 0.9), 0.4)
		_put(InteriorParts.stool(), Vector3(0.8, 0, 0.0), -0.6)
	if _use("wardrobe"):
		_put(InteriorParts.wardrobe(), Vector3(east - 0.2, 0, 2.4), FACE_MINUS_X)
	if _use("plant"):
		_put(InteriorParts.plant(), Vector3(hx - 0.7, 0, hz - 0.8))
		_put(InteriorParts.plant(), Vector3(-1.9, 0, hz - 0.7))
	if _use("chandelier"):
		_put(InteriorParts.chandelier(1.3), Vector3(-0.6, ceiling_height, 0.5))
	if _use("motes"):
		var motes := InteriorParts.floating_motes(Vector3(hx - 0.5, 1.5, hz - 0.5))
		_put(motes, Vector3(0, 1.8, 0))
