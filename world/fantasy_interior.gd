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

## HOME: the player's cosy cottage. HALL: the mayor's study (a smaller, grander room). SHOP: the shopkeeper's store. CAT_LADY / BAKERY / KIDS_HOME: Mrs. Vael's, Marta's and Yule's houses.
enum Layout { HOME, HALL, SHOP, CAT_LADY, BAKERY, KIDS_HOME }
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
const FACE_MINUS_Z := PI
const FURNITURE := "res://assets/blender_stuff/Cute_Furniture_Free_glb/Separate_Assets_glb/"
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
		Layout.SHOP:
			_build_shop()
		Layout.CAT_LADY:
			_build_cat_lady()
		Layout.BAKERY:
			_build_bakery()
		Layout.KIDS_HOME:
			_build_kids_home()
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

## The shopkeeper's store: a counter across the room's west half (the keeper stands behind
## it, placed in the scene), goods shelves on the back wall, barrels, crates and sacks by
## the door, a display table, a shield and banner, a window and two chandeliers.
func _build_shop() -> void:
	var hx := room_size.x * 0.5
	var hz := room_size.y * 0.5
	if _use("rug"):
		_put(InteriorParts.runner(2.0, 4.6, Color(0.4, 0.14, 0.2), Color(0.8, 0.62, 0.25)), Vector3(0.6, 0, 1.6))
	if _use("counter"):
		_put(InteriorParts.counter(4.4), Vector3(-hx + 2.4, 0, -1.2))
	if _use("shelves"):
		_put(InteriorParts.shelf(2.3, 3.4, InteriorParts.Fill.POTIONS, seed_value), Vector3(-2.8, 0, -hz + 0.45))
		_put(InteriorParts.shelf(2.3, 3.4, InteriorParts.Fill.JARS, seed_value + 1), Vector3(-0.3, 0, -hz + 0.45))
		_put(InteriorParts.shelf(2.3, 3.4, InteriorParts.Fill.BOOKS, seed_value + 2), Vector3(2.2, 0, -hz + 0.45))
		_put(InteriorParts.shelf(2.0, 2.8, InteriorParts.Fill.POTIONS, seed_value + 3), Vector3(hx - 0.4, 0, 0.2), FACE_MINUS_X)
	if _use("decor"):
		_put(InteriorParts.shield(), Vector3(hx - 0.1, 3.4, -1.8), FACE_MINUS_X)
		_put(InteriorParts.banner(InteriorParts.ROOF_RED), Vector3(hx - 0.1, 1.0, -2.8), FACE_MINUS_X)
		_put(InteriorParts.window(1.4, 1.6), Vector3(-hx + 0.06, 2.5, 1.8), FACE_PLUS_X)
		_put(InteriorParts.picture(0.9, 0.7, Color(0.7, 0.5, 0.3)), Vector3(-hx + 0.06, 2.8, 0.1), FACE_PLUS_X)
	if _use("stock"):
		_put(InteriorParts.barrel(), Vector3(hx - 0.7, 0, hz - 0.6))
		_put(InteriorParts.barrel(), Vector3(hx - 0.7, 0, hz - 1.6))
		_put(InteriorParts.sack(Color(0.78, 0.68, 0.45)), Vector3(hx - 1.6, 0, hz - 0.6))
		_put(InteriorParts.crate(0.85), Vector3(-hx + 0.7, 0, hz - 0.6), 0.2)
		_put(InteriorParts.crate(0.7), Vector3(-hx + 1.55, 0, hz - 0.55), -0.15)
		_put(InteriorParts.crate(0.6), Vector3(-hx + 0.75, 0.85, hz - 0.6), 0.4)
	if _use("table"):
		_put(InteriorParts.table(0.7), Vector3(2.3, 0, 1.0))
	if _use("plant"):
		_put(InteriorParts.plant(), Vector3(1.9, 0, hz - 0.7))
	if _use("chandelier"):
		_put(InteriorParts.chandelier(1.3), Vector3(-1.2, ceiling_height, -0.6))
		_put(InteriorParts.chandelier(1.3), Vector3(1.4, ceiling_height, 1.8))
	if _use("motes"):
		_put(InteriorParts.floating_motes(Vector3(hx - 0.5, 1.5, hz - 0.5)), Vector3(0, 1.8, 0))

func _furniture(file: String) -> Node3D:
	return InteriorParts.model(FURNITURE + file + ".glb")

## Mrs. Vael's house: cosy and cat-crazy. A hearth with her armchair and yarn, a pet bed
## by the fire (Biscuit comes home to it), a cat tree, cat pictures, a couch, books and tea.
func _build_cat_lady() -> void:
	var hx := room_size.x * 0.5
	var hz := room_size.y * 0.5
	if _use("rug"):
		_put(InteriorParts.rug(1.9, Color(0.62, 0.3, 0.42), Color(0.85, 0.68, 0.3)), Vector3(0.2, 0, 0.5))
	if _use("fireplace"):
		_put(InteriorParts.fireplace(), Vector3(-hx + 0.52, 0, -0.2), FACE_PLUS_X)
	if _use("furniture"):
		_put(_furniture("Armchair_18"), Vector3(-0.4, 0, -1.6), FACE_MINUS_X)
		_put(_furniture("Couch_08"), Vector3(-1.0, 0, -hz + 0.6))
		_put(_furniture("Nightstand_02"), Vector3(0.5, 0, -hz + 0.15))
		_put(InteriorParts.yarn_basket(), Vector3(-0.5, 0, -0.7))
		_put(InteriorParts.cushion(Color(0.85, 0.5, 0.55)), Vector3(-1.1, 0, 1.0))   # Biscuit's bed
		_put(InteriorParts.cat_tree(), Vector3(hx - 0.8, 0, -hz + 1.0))
		_put(InteriorParts.table(0.6), Vector3(1.7, 0, 1.2))
		_put(InteriorParts.stool(), Vector3(1.0, 0, 1.9), 0.3)
		_put(InteriorParts.stool(), Vector3(2.4, 0, 1.9), -0.3)
	if _use("shelves"):
		_put(InteriorParts.shelf(2.0, 3.0, InteriorParts.Fill.BOOKS, seed_value), Vector3(1.5, 0, -hz + 0.45))
	if _use("decor"):
		_put(InteriorParts.window(1.3, 1.6), Vector3(hx - 0.06, 2.5, 0.3), FACE_MINUS_X)
		for i in 3:   # portraits of Biscuit
			_put(InteriorParts.picture(0.6 + 0.1 * (i % 2), 0.7, Color(0.9, 0.55, 0.2)), Vector3(hx - 0.06, 2.6 - 0.1 * (i % 2), -1.4 - 0.9 * i), FACE_MINUS_X)
	if _use("plant"):
		_put(InteriorParts.plant(), Vector3(-hx + 0.6, 0, hz - 0.6))
		_put(InteriorParts.plant(), Vector3(hx - 0.6, 0, hz - 0.6))
	if _use("chandelier"):
		_put(InteriorParts.chandelier(1.3), Vector3(0.2, ceiling_height, 0.4))
	if _use("motes"):
		_put(InteriorParts.floating_motes(Vector3(hx - 0.5, 1.5, hz - 0.5)), Vector3(0, 1.8, 0))

## Marta's bakery: a brick oven with a roaring fire, a worktable of dough, shelves of bread,
## a counter (she stands behind it, placed in the scene), flour sacks and a few tables.
func _build_bakery() -> void:
	var hx := room_size.x * 0.5
	var hz := room_size.y * 0.5
	if _use("rug"):
		_put(InteriorParts.rug(1.5, Color(0.55, 0.28, 0.2), Color(0.9, 0.78, 0.5)), Vector3(-1.9, 0, 1.4))
	if _use("oven"):
		_put(InteriorParts.oven(), Vector3(-hx + 2.0, 0, -hz + 1.0))
	if _use("worktable"):
		_put(InteriorParts.worktable(2.8), Vector3(-hx + 1.0, 0, 0.7), FACE_PLUS_X)
	if _use("counter"):
		_put(InteriorParts.counter(4.0), Vector3(hx - 2.3, 0, -0.6))
	if _use("shelves"):
		_put(InteriorParts.shelf(2.4, 3.2, InteriorParts.Fill.BREAD, seed_value), Vector3(0.6, 0, -hz + 0.45))
		_put(InteriorParts.shelf(2.4, 3.2, InteriorParts.Fill.BREAD, seed_value + 1), Vector3(3.0, 0, -hz + 0.45))
		_put(InteriorParts.shelf(1.8, 2.6, InteriorParts.Fill.JARS, seed_value + 2), Vector3(hx - 0.4, 0, 1.6), FACE_MINUS_X)
	if _use("stock"):
		_put(InteriorParts.sack(Color(0.95, 0.93, 0.85)), Vector3(hx - 0.7, 0, hz - 0.7))
		_put(InteriorParts.sack(Color(0.95, 0.93, 0.85)), Vector3(hx - 1.6, 0, hz - 0.6))
		_put(InteriorParts.sack(Color(0.9, 0.88, 0.8)), Vector3(hx - 0.6, 0, hz - 1.6))
		_put(InteriorParts.barrel(), Vector3(-hx + 0.7, 0, hz - 0.7))
		_put(InteriorParts.crate(0.8), Vector3(-hx + 1.7, 0, hz - 0.6), 0.2)
	if _use("table"):
		_put(InteriorParts.table(0.7), Vector3(-1.9, 0, 1.4))
		_put(InteriorParts.stool(), Vector3(-2.9, 0, 1.4), 0.4)
		_put(InteriorParts.stool(), Vector3(-0.9, 0, 1.6), -0.4)
	if _use("decor"):
		_put(InteriorParts.window(1.4, 1.6), Vector3(hx - 0.06, 2.5, -2.2), FACE_MINUS_X)
		_put(InteriorParts.banner(InteriorParts.ROOF_RED), Vector3(-hx + 0.1, 1.0, 0.6), FACE_PLUS_X)
		_put(InteriorParts.picture(0.8, 0.6, Color(0.8, 0.6, 0.3)), Vector3(1.9, 2.6, hz - 0.06), FACE_MINUS_Z)
	if _use("plant"):
		_put(InteriorParts.plant(), Vector3(1.8, 0, hz - 0.6))
	if _use("chandelier"):
		_put(InteriorParts.chandelier(1.3), Vector3(-1.6, ceiling_height, 0.8))
		_put(InteriorParts.chandelier(1.3), Vector3(2.0, ceiling_height, 0.6))
	if _use("motes"):
		_put(InteriorParts.floating_motes(Vector3(hx - 0.5, 1.5, hz - 0.5)), Vector3(0, 1.8, 0))

## Yule's house (she stands outside it): two beds, a nightstand, toys on a bright rug, a
## small hearth, drawings and a kite on the walls, and a clock.
func _build_kids_home() -> void:
	var hx := room_size.x * 0.5
	var hz := room_size.y * 0.5
	if _use("rug"):
		_put(InteriorParts.rug(1.7, Color(0.3, 0.5, 0.72), Color(0.95, 0.75, 0.3)), Vector3(0.3, 0, 0.7))
	if _use("fireplace"):
		_put(InteriorParts.fireplace(), Vector3(-hx + 0.52, 0, 0.9), FACE_PLUS_X)
	if _use("furniture"):
		_put(_furniture("Bed_02"), Vector3(-hx + 1.3, 0, -hz + 1.3))
		_put(_furniture("Bed_07"), Vector3(hx - 1.2, 0, -hz + 1.4))
		_put(_furniture("Nightstand_02"), Vector3(0.1, 0, -hz + 0.15))
		_put(_furniture("Clock_03"), Vector3(hx - 0.5, 0, 2.4), FACE_MINUS_X)
		_put(InteriorParts.toy_blocks(), Vector3(-0.2, 0, 0.5), 0.3)
		_put(InteriorParts.toy_horse(), Vector3(1.0, 0, 1.2), 0.9)
		_put(InteriorParts.table(0.6), Vector3(1.7, 0, -0.5))
		_put(InteriorParts.stool(), Vector3(1.0, 0, -0.5), 0.2)
	if _use("decor"):
		_put(InteriorParts.kite(Color(0.9, 0.35, 0.4)), Vector3(0.1, 2.7, -hz + 0.07))
		_put(InteriorParts.window(1.2, 1.5), Vector3(hx - 0.06, 2.5, 0.8), FACE_MINUS_X)
		for i in 3:   # her drawings
			_put(InteriorParts.picture(0.5, 0.4, Color(0.5 + 0.15 * i, 0.6, 0.4)), Vector3(hx - 0.06, 2.4 + 0.1 * (i % 2), -0.9 - 0.7 * i), FACE_MINUS_X)
	if _use("shelves"):
		_put(InteriorParts.shelf(1.6, 2.4, InteriorParts.Fill.BOOKS, seed_value), Vector3(-hx + 0.4, 0, hz - 1.4), FACE_PLUS_X)
	if _use("plant"):
		_put(InteriorParts.plant(), Vector3(hx - 0.6, 0, hz - 0.7))
	if _use("chandelier"):
		_put(InteriorParts.chandelier(1.3), Vector3(0.0, ceiling_height, 0.8))
	if _use("motes"):
		_put(InteriorParts.floating_motes(Vector3(hx - 0.5, 1.5, hz - 0.5)), Vector3(0, 1.8, 0))

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
