@tool
class_name HouseExtras
extends Node
## The second dressing pass for the Chesburg houses (HouseDressing does roofs, chimneys,
## signs and awnings): the everyday things that make a street look lived in — a lantern by the door, bunting, laundry,
## a market stall, crates and barrels, a wood pile, wind chimes, a notice board whose
## notes follow the quest flags.
##
## Each prop is a PropSlot node, placed the first time from the house's own door, front wall
## and facade width (see RoofProbe). The slots of a house sit under a plain "Extras_N" node
## next to the house (not inside the house model, which would make a click in the viewport
## select the whole house). In the editor they are real, saved nodes: CLICK ONE IN THE 3D
## VIEW, then MOVE, ROTATE, DELETE OR DUPLICATE IT, and save the scene. Once a house
## has slots this script leaves it alone, so your changes stick; press "Reset extras" to throw
## them all away and lay them out again from the PLAN table (also the way to pick up new
## entries in PLAN).
##
## Keys per house in PLAN (all optional):
##   lantern        -1 / 1    side of the door for the hanging lantern
##   bunting        true      a string of pennants left of the door
##   laundry        true      a clothes line on the right-hand side of the yard
##   woodpile       true      logs stacked against the left-hand side wall
##   stall          float     x offset (from the door) of a market stall out front
##   barrels        float     x offset of a cluster of crates and barrels against the front wall
##   chimes         -1 / 1    wind chimes beside the door
##   notice         true      a notice board in the front yard (left of the door)
##   perches        true      two bird perches on the roof ridge (the Birds flock lands there)
##   cat            true      a cat sitting on the roof ridge (RoofCat)
##   chickens       float     x offset of a hen yard out front (Chickens)

const PLAN := {
	"house_chesburg_1": {"lantern": 1, "woodpile": true, "perches": true, "chickens": 4.8},
	"house_chesburg_2": {"lantern": -1, "notice": true, "perches": true},
	"house_chesburg_3": {"lantern": 1, "bunting": true, "perches": true},
	"house_chesburg_4": {"lantern": 1, "bunting": true, "barrels": -3.0, "perches": true, "cat": true},
	"house_chesburg_5": {"lantern": -1, "laundry": true, "chimes": 1, "perches": true},
	"house_chesburg_6": {"lantern": 1, "bunting": true, "stall": 4.4, "barrels": -3.0, "perches": true},
}

const WALL_SINK := 0.08            ## wall decorations sink this far into the wall: no gap
const LANTERN_SINK := 0.3          ## the lantern mounts this far inside the wall, same as the hanging signs (HouseDressing.WALL_OVERLAP)
const LANTERN_X := 1.05
const LANTERN_HEIGHT := 2.15
const BUNTING_HEIGHT := 3.6
const NOTICE_X := -3.8
const NOTICE_OUT := 1.8            ## how far in front of the wall the notice board stands
const STALL_OUT := 2.6
const CHIMES_HEIGHT := 2.35
const CHICKENS_OUT := 3.6

@export var name_filter: PackedStringArray = ["house_chesburg"]

## Click in the inspector to delete every prop on these houses and lay them out again from PLAN.
@export_tool_button("Reset extras") var reset_button := _reset

func _ready() -> void:
	# Deferred: in the editor the houses' meshes and doors may not be in place yet.
	_dress_all.call_deferred(false)

func _reset() -> void:
	_dress_all(true)

func _dress_all(reset: bool) -> void:
	var holder := get_parent()
	if holder == null or not is_inside_tree():
		return
	var made := 0
	for child in holder.get_children():
		if child is Node3D and _matches(child.name) and PLAN.has(String(child.name)):
			var house := child as Node3D
			if reset or not _has_slots(house):
				_remove_slots(house)   # (also clears slots left inside the house by an earlier version)
			if _has_slots(house):
				continue   # already laid out (and maybe moved by hand): leave it
			made += _dress(house, PLAN[String(child.name)])
	if Engine.is_editor_hint() and made > 0:
		print("HouseExtras: laid out %d props - save the scene (Ctrl+S) to keep them, then move them freely" % made)

func _matches(node_name: String) -> bool:
	for f in name_filter:
		if node_name.containsn(f):
			return true
	return false

const HOLDER_PREFIX := "Extras_"

## The node that holds a house's slots, or null: "Extras_<n>" beside the house.
func _holder_of(house: Node3D) -> Node3D:
	return house.get_parent().get_node_or_null(HOLDER_PREFIX + String(house.name).get_slice("_", 2)) as Node3D

func _has_slots(house: Node3D) -> bool:
	var holder := _holder_of(house)
	if holder == null:
		return false
	for child in holder.get_children():
		if child is PropSlot:
			return true
	return false

## Removes a house's slots: its holder, and any slots an earlier version put inside the house itself.
func _remove_slots(house: Node3D) -> void:
	var holder := _holder_of(house)
	if holder != null:
		holder.get_parent().remove_child(holder)
		holder.queue_free()
	for child in house.get_children():
		if child is PropSlot:
			house.remove_child(child)
			child.queue_free()

## The holder for `house`, made (unscaled, at the house's position and rotation) if missing.
func _ensure_holder(house: Node3D) -> Node3D:
	var holder := _holder_of(house)
	if holder != null:
		return holder
	holder = Node3D.new()
	holder.name = HOLDER_PREFIX + String(house.name).get_slice("_", 2)
	holder.transform = Transform3D(house.basis.orthonormalized(), house.position)
	house.get_parent().add_child(holder)
	if Engine.is_editor_hint():
		_own(holder)
	return holder

func _own(node: Node) -> void:
	var root := get_tree().edited_scene_root
	if root != null and root.is_ancestor_of(node):
		node.owner = root

## Lays out `plan`'s props on `house`; returns how many slots it made.
func _dress(house: Node3D, plan: Dictionary) -> int:
	var door := HouseMount.door_of(house)
	if door == null:
		push_warning("HouseExtras: %s has no Door_* child, so it gets no extras" % house.name)
		return 0
	var ctx := {
		"house": house,
		"x0": door.position.x,
		"floor": door.position.y - HouseMount.DOOR_FLOOR_DROP,
		"span": RoofProbe.front_wall_span(house),
		"count": 0,
	}
	if plan.has("lantern"):
		var x: float = ctx["x0"] + float(plan["lantern"]) * LANTERN_X
		_slot(ctx, "Lantern", PropSlot.Kind.LANTERN, Vector3(x, float(ctx["floor"]) + LANTERN_HEIGHT, _wall(ctx, x) - LANTERN_SINK))
	if plan.get("bunting", false):
		_add_bunting(ctx)
	if plan.get("laundry", false):
		_add_laundry(ctx)
	if plan.get("woodpile", false):
		_add_woodpile(ctx)
	if plan.has("stall"):
		var x: float = ctx["x0"] + float(plan["stall"])
		_slot(ctx, "Stall", PropSlot.Kind.STALL, Vector3(x, float(ctx["floor"]), _wall(ctx, ctx["x0"]) + STALL_OUT))
	if plan.has("barrels"):
		var x: float = ctx["x0"] + float(plan["barrels"])
		_slot(ctx, "CratesAndBarrels", PropSlot.Kind.CRATES_AND_BARRELS, Vector3(x, float(ctx["floor"]), _wall(ctx, x) + 0.55))
	if plan.has("chimes"):
		var x: float = ctx["x0"] + float(plan["chimes"]) * (LANTERN_X + 0.15)
		_slot(ctx, "WindChimes", PropSlot.Kind.WIND_CHIMES, Vector3(x, float(ctx["floor"]) + CHIMES_HEIGHT, _wall(ctx, x) - WALL_SINK))
	if plan.get("notice", false):
		var x: float = ctx["x0"] + NOTICE_X
		_slot(ctx, "NoticeBoard", PropSlot.Kind.NOTICE_BOARD, Vector3(x, float(ctx["floor"]), _wall(ctx, ctx["x0"]) + NOTICE_OUT))
	if plan.get("perches", false) or plan.get("cat", false):
		_add_roof_animals(ctx, plan)
	if plan.has("chickens"):
		var x: float = ctx["x0"] + float(plan["chickens"])
		_slot(ctx, "Chickens", PropSlot.Kind.CHICKENS, Vector3(x, float(ctx["floor"]), _wall(ctx, ctx["x0"]) + CHICKENS_OUT))
	return int(ctx["count"])

# ----------------------------------------------------------------- helpers

func _wall(ctx: Dictionary, x: float) -> float:
	return HouseMount.wall_z(ctx["house"], x, ctx["floor"])

## Adds one PropSlot for the house. `pos` is in the house's own space; the slot lives in the
## house's holder, which has the house's position and rotation but no scale, so the position
## is stretched by the house's scale here (and a squashed house doesn't squash its props).
func _slot(ctx: Dictionary, slot_name: String, kind: PropSlot.Kind, pos: Vector3, yaw := 0.0, length := 4.0) -> void:
	var house: Node3D = ctx["house"]
	var slot := PropSlot.new()
	slot.name = slot_name
	slot.kind = kind
	slot.length = length
	slot.position = pos * house.basis.get_scale()
	slot.rotation.y = yaw
	_ensure_holder(house).add_child(slot)
	if Engine.is_editor_hint():
		_own(slot)
	ctx["count"] = int(ctx["count"]) + 1

# ------------------------------------------------------------------ pieces

func _add_bunting(ctx: Dictionary) -> void:
	var span: Vector2 = ctx["span"]
	if is_nan(span.x):
		return
	var x_from := span.x + 0.3
	var x_to: float = ctx["x0"] - 1.5   # stops short of the door, its sign and lantern
	if x_to - x_from < 1.5:
		return
	_slot(ctx, "Bunting", PropSlot.Kind.BUNTING, Vector3(x_from, float(ctx["floor"]) + BUNTING_HEIGHT, _wall(ctx, x_from) + 0.2), 0.0, x_to - x_from)

func _add_laundry(ctx: Dictionary) -> void:
	var span: Vector2 = ctx["span"]
	if is_nan(span.y):
		return
	# beside the right-hand wall, running back from the front corner
	_slot(ctx, "LaundryLine", PropSlot.Kind.LAUNDRY_LINE, Vector3(span.y + 0.9, float(ctx["floor"]), _wall(ctx, ctx["x0"]) - 0.8), PI * 0.5, 3.4)

func _add_woodpile(ctx: Dictionary) -> void:
	var span: Vector2 = ctx["span"]
	if is_nan(span.x):
		return
	_slot(ctx, "WoodPile", PropSlot.Kind.WOOD_PILE, Vector3(span.x - 0.8, float(ctx["floor"]), _wall(ctx, ctx["x0"]) - 1.2), PI * 0.5)

## Roof points along the ridge worth sitting on: the highest roof spot and up to two
## neighbours 1.6 m away that are about as high (so they sit on the ridge, not on a slope).
func _ridge_points(house: Node3D) -> Array[Vector3]:
	var top := RoofProbe.ridge(house, Vector2.ZERO)
	var points: Array[Vector3] = []
	if top.is_empty():
		return points
	var rx := float(top["x"])
	var rz := float(top["z"])
	var ry := float(top["y"])
	for offset in [Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(0, -1.6), Vector2(0, 1.6)]:
		var s := RoofProbe.sample(house, Vector2(rx, rz) + offset)
		if not s.is_empty() and float(s["y"]) >= ry - 0.2:
			points.append(Vector3(rx + offset.x, float(s["y"]) - 0.02, rz + offset.y))
	return points

func _add_roof_animals(ctx: Dictionary, plan: Dictionary) -> void:
	var points := _ridge_points(ctx["house"])
	if plan.get("perches", false):
		for i in mini(points.size(), 2):
			_slot(ctx, "BirdPerch%d" % (i + 1), PropSlot.Kind.BIRD_PERCH, points[i])
	if plan.get("cat", false) and not points.is_empty():
		_slot(ctx, "RoofCat", PropSlot.Kind.ROOF_CAT, points.back())
