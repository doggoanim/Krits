class_name ShopLife
extends Node
## Makes a shop look like it opens and closes: a little OPEN / CLOSED board hangs by the door
## and flips with the door's hours (Door.open_from / open_to), and the goods outside (the
## market stall, crates and barrels) are carried out in the morning and taken in at dusk,
## popping in and out in held poses (see Choppy). While they are away their collision is off.
##
## Put one in the level and point it at the shop's Door and its outside goods (any Node3D,
## e.g. the PropSlots HouseExtras made). Goods can follow their own hours (`goods_from` /
## `goods_to`, WorldClock hours; -1 = same as the door).

@export var door_path: NodePath
@export var goods_paths: Array[NodePath] = []
@export var goods_from := -1.0
@export var goods_to := -1.0
@export var side_offset := -1.0                       ## sideways from the door's middle, in the door's own space: negative = the viewer's left
@export var height_offset := 0.45                     ## above the door node (which sits 1 m above the floor)
@export var wall_gap := 0.03                          ## how far the board's middle stands off the wall face (the name sign is flush, at 0)
@export var open_color := Color(0.4, 0.8, 0.4)
@export var closed_color := Color(0.85, 0.35, 0.3)
@export var pop_steps := 5                            ## poses a good takes to appear or vanish

const FLIP_STEPS := 4

class Good:
	var node: Node3D
	var rest_scale := Vector3.ONE
	var shown := true
	var progress := 1.0     ## 0 = away, 1 = out (stepped towards `shown`)

var _door: Door
var _goods: Array[Good] = []
var _board: Node3D
var _label: Label3D
var _board_open := true
var _flip := 1.0            ## 0 .. 1: how far through the flip to the current face
var _last_step := -1

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_door = get_node_or_null(door_path) as Door
	for path in goods_paths:
		var n := get_node_or_null(path) as Node3D
		if n != null:
			var g := Good.new()
			g.node = n
			g.rest_scale = n.scale
			_goods.append(g)
	if _door != null:
		_build_board()
	_snap()
	set_process(true)

func _door_open() -> bool:
	return _door != null and _door.is_open()

func _goods_out() -> bool:
	if goods_from >= 0.0 and goods_to >= 0.0:
		return WorldClock.in_range(goods_from, goods_to)
	return _door_open()

## Everything straight to its current state (level load: nobody sees the setup).
func _snap() -> void:
	var out := _goods_out()
	for g in _goods:
		g.shown = out
		g.progress = 1.0 if out else 0.0
		_apply_good(g)
	_board_open = _door_open()
	_flip = 1.0
	_apply_board()

func _process(_delta: float) -> void:
	var step := Choppy.index()
	if step == _last_step:
		return
	_last_step = step
	var out := _goods_out()
	for g in _goods:
		g.shown = out
		var target := 1.0 if out else 0.0
		if g.progress != target:
			g.progress = move_toward(g.progress, target, 1.0 / maxf(float(pop_steps), 1.0))
			_apply_good(g)
	if _board != null:
		var open := _door_open()
		if open != _board_open:
			_board_open = open
			_flip = 0.0
		if _flip < 1.0:
			_flip = minf(_flip + 1.0 / FLIP_STEPS, 1.0)
			_apply_board()

# --- goods -------------------------------------------------------------------------

func _apply_good(g: Good) -> void:
	if not is_instance_valid(g.node):
		return
	var k := g.progress
	# a small overshoot as it pops out, so it reads as being set down
	var eased := k if k >= 1.0 or k <= 0.0 else k * (1.0 + 0.25 * sin(k * PI))
	g.node.visible = k > 0.0
	g.node.scale = g.rest_scale * maxf(eased, 0.001)
	_set_collision(g.node, k >= 1.0)

func _set_collision(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", not enabled)
	for child in node.get_children():
		_set_collision(child, enabled)

# --- the OPEN / CLOSED board ----------------------------------------------------------

func _build_board() -> void:
	_board = Node3D.new()
	_board.name = "OpenClosedBoard"
	_door.add_child(_board)
	_board.position = Vector3(side_offset, height_offset, _wall_local_z() + wall_gap)
	var wood := Color(0.42, 0.28, 0.16)
	HouseParts.box(_board, Vector3(0.62, 0.3, 0.08), wood, Vector3.ZERO)
	HouseParts.box(_board, Vector3(0.66, 0.04, 0.07), wood.darkened(0.3), Vector3(0, 0.17, 0))
	HouseParts.box(_board, Vector3(0.02, 0.2, 0.02), Color(0.2, 0.2, 0.22), Vector3(-0.2, 0.28, 0))   # two short chains
	HouseParts.box(_board, Vector3(0.02, 0.2, 0.02), Color(0.2, 0.2, 0.22), Vector3(0.2, 0.28, 0))
	_label = Label3D.new()
	_label.font_size = 44
	_label.pixel_size = 0.0045
	_label.outline_size = 10
	_label.outline_modulate = Color(0.08, 0.06, 0.05)
	_label.position = Vector3(0, 0, 0.045)
	_label.double_sided = false
	_board.add_child(_label)

## The wall face in front of the door, in the door's own space: the same wall the name sign is
## mounted on (HouseMount), so the board stands off the wall by exactly as much.
func _wall_local_z() -> float:
	var house := _door.get_parent() as Node3D
	if house == null:
		return HouseMount.DOOR_WALL_OFFSET
	var floor_y := _door.position.y - HouseMount.DOOR_FLOOR_DROP
	var wall := HouseMount.wall_z(house, _door.position.x + side_offset, floor_y)
	return wall - _door.position.z

func _apply_board() -> void:
	if _board == null:
		return
	# The board turns over in a few held poses: edge-on halfway, and the new word shows from there.
	var face_open := _board_open if _flip >= 0.5 else not _board_open
	_board.scale.x = maxf(absf(cos(_flip * PI)), 0.05)
	_label.text = "OPEN" if face_open else "CLOSED"
	_label.modulate = open_color if face_open else closed_color
