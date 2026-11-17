@tool
class_name HouseExtras
extends Node
## The second dressing pass for the Chesburg houses (HouseDressing does roofs, chimneys,
## signs and awnings): the everyday things that make a street look lived in — windows with
## shutters and flower boxes that glow after dusk, a lantern by the door, bunting, laundry,
## a market stall, crates and barrels, a wood pile, wind chimes, a notice board whose
## notes follow the quest flags.
##
## Everything is found from the house itself (its door, its front wall, how wide the facade
## is — see RoofProbe), so it follows a house if you move or scale it. Like HouseDressing it
## runs in the editor too; parts are ownerless children, shown in the viewport and never
## saved into the scene.
##
## What each house gets is the PLAN table below — edit it to move things around; nothing
## else needs to change. Keys per house (all optional):
##   windows        [-1, 1]   which sides of the door get a window (-1 left, +1 right, as seen facing the house)
##   window_pairs   1 / 2     how many windows per side (wide houses take 2)
##   shutter        Color     shutter paint
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
	"house_chesburg_1": {"windows": [-1, 1], "shutter": Color(0.3, 0.5, 0.35), "lantern": 1, "woodpile": true, "perches": true, "chickens": 4.8},
	"house_chesburg_2": {"windows": [-1], "shutter": Color(0.55, 0.38, 0.6), "lantern": -1, "notice": true, "perches": true},
	"house_chesburg_3": {"lantern": 1, "bunting": true, "perches": true},
	"house_chesburg_4": {"windows": [-1, 1], "window_pairs": 2, "shutter": Color(0.82, 0.52, 0.25), "lantern": 1, "bunting": true, "barrels": -3.0, "perches": true, "cat": true},
	"house_chesburg_5": {"windows": [-1, 1], "shutter": Color(0.3, 0.45, 0.72), "lantern": -1, "laundry": true, "chimes": 1, "perches": true},
	"house_chesburg_6": {"windows": [-1, 1], "shutter": Color(0.62, 0.22, 0.2), "lantern": 1, "bunting": true, "stall": 4.4, "barrels": -3.0, "perches": true},
}

const META := &"house_extra"
const WINDOW_FIRST := 1.95         ## door -> first window centre (m)
const WINDOW_STEP := 1.9           ## door -> next window along the wall
const WINDOW_HEIGHT := 1.55        ## window centre above the floor
const WINDOW_CLEARANCE := 1.0      ## the wall must continue this far past a window's centre (shutters)
const WALL_SINK := 0.03            ## wall decorations sink this far into the wall: no gap
const LANTERN_X := 1.05
const LANTERN_HEIGHT := 2.15
const BUNTING_HEIGHT := 3.6
const NOTICE_X := -3.8
const NOTICE_OUT := 1.8            ## how far in front of the wall the notice board stands
const STALL_OUT := 2.6
const CHIMES_HEIGHT := 2.35
const HAMMER_SFX := ["res://sounds/SFX/others/hammer_tink.ogg"]
const CHOP_SFX := ["res://sounds/SFX/others/wood_chop.ogg"]

@export var name_filter: PackedStringArray = ["house_chesburg"]

## Click in the inspector to rebuild everything (e.g. after editing PLAN).
@export_tool_button("Rebuild extras") var rebuild_button := _dress_all

func _ready() -> void:
	# Deferred: in the editor the houses' meshes and doors may not be in place yet.
	_dress_all.call_deferred()

func _dress_all() -> void:
	var holder := get_parent()
	if holder == null or not is_inside_tree():
		return
	var count := 0
	for child in holder.get_children():
		if child is Node3D and _matches(child.name) and PLAN.has(String(child.name)):
			_dress(child as Node3D, PLAN[String(child.name)])
			count += 1
	if Engine.is_editor_hint():
		print("HouseExtras: dressed %d houses" % count)

func _matches(node_name: String) -> bool:
	for f in name_filter:
		if node_name.containsn(f):
			return true
	return false

func _dress(house: Node3D, plan: Dictionary) -> void:
	HouseMount.clear(house, META)
	var door := HouseMount.door_of(house)
	if door == null:
		push_warning("HouseExtras: %s has no Door_* child, so it gets no extras" % house.name)
		return
	var ctx := {
		"house": house,
		"x0": door.position.x,
		"floor": door.position.y - HouseMount.DOOR_FLOOR_DROP,
		"span": RoofProbe.front_wall_span(house),
	}
	if plan.has("windows"):
		_add_windows(ctx, plan)
	if plan.has("lantern"):
		_add_lantern(ctx, float(plan["lantern"]))
	if plan.get("bunting", false):
		_add_bunting(ctx)
	if plan.get("laundry", false):
		_add_laundry(ctx)
	if plan.get("woodpile", false):
		_add_woodpile(ctx)
	if plan.has("stall"):
		_add_stall(ctx, float(plan["stall"]))
	if plan.has("barrels"):
		_add_barrels(ctx, float(plan["barrels"]))
	if plan.has("chimes"):
		_add_chimes(ctx, float(plan["chimes"]))
	if plan.get("notice", false):
		_add_notice_board(ctx)
	if plan.get("perches", false):
		_add_perches(ctx)
	if plan.get("cat", false):
		_add_cat(ctx)
	if plan.has("chickens"):
		_add_chickens(ctx, float(plan["chickens"]))

# ----------------------------------------------------------------- helpers

func _wall(ctx: Dictionary, x: float) -> float:
	return HouseMount.wall_z(ctx["house"], x, ctx["floor"])

func _put(ctx: Dictionary, part: Node3D, pos: Vector3, yaw := 0.0) -> void:
	HouseMount.place(ctx["house"], part, META, pos, yaw)

## Is there wall left at x (given the facade's width) for something `half` wide?
func _fits(ctx: Dictionary, x: float, half: float) -> bool:
	var span: Vector2 = ctx["span"]
	return not is_nan(span.x) and x - half >= span.x and x + half <= span.y

# ------------------------------------------------------------------ pieces

func _add_windows(ctx: Dictionary, plan: Dictionary) -> void:
	var shutter: Color = plan.get("shutter", Color(0.3, 0.5, 0.35))
	for side in plan["windows"]:
		for k in int(plan.get("window_pairs", 1)):
			var x: float = ctx["x0"] + float(side) * (WINDOW_FIRST + WINDOW_STEP * k)
			if not _fits(ctx, x, WINDOW_CLEARANCE):
				continue
			var shade := shutter if k == 0 else shutter.lerp(HouseParts.WOOD_DARK, 0.35)
			_put(ctx, HouseProps.window_lit(shade, true), Vector3(x, float(ctx["floor"]) + WINDOW_HEIGHT, _wall(ctx, x) - WALL_SINK))

func _add_lantern(ctx: Dictionary, side: float) -> void:
	var x: float = ctx["x0"] + side * LANTERN_X
	_put(ctx, HouseProps.lantern(), Vector3(x, float(ctx["floor"]) + LANTERN_HEIGHT, _wall(ctx, x) - WALL_SINK))

func _add_bunting(ctx: Dictionary) -> void:
	var span: Vector2 = ctx["span"]
	if is_nan(span.x):
		return
	var x_from := span.x + 0.3
	var x_to: float = ctx["x0"] - 1.5   # stops short of the door, its sign and lantern
	if x_to - x_from < 1.5:
		return
	var length := x_to - x_from
	_put(ctx, HouseProps.bunting(length, maxi(int(length / 0.45), 4)), Vector3(x_from, float(ctx["floor"]) + BUNTING_HEIGHT, _wall(ctx, x_from) + 0.2))

func _add_laundry(ctx: Dictionary) -> void:
	var span: Vector2 = ctx["span"]
	if is_nan(span.y):
		return
	var front := _wall(ctx, ctx["x0"])
	# beside the right-hand wall, running back from the front corner
	_put(ctx, HouseProps.laundry_line(3.4, 4), Vector3(span.y + 0.9, float(ctx["floor"]), front - 0.8), PI * 0.5)

func _add_woodpile(ctx: Dictionary) -> void:
	var span: Vector2 = ctx["span"]
	if is_nan(span.x):
		return
	var front := _wall(ctx, ctx["x0"])
	var pile := HouseProps.wood_pile()
	pile.add_child(_one_shots(CHOP_SFX, 14.0, 40.0, 7.0, 18.5, Vector3(1.9, 0.8, 0.5)))   # someone splitting logs by day
	_put(ctx, pile, Vector3(span.x - 0.8, float(ctx["floor"]), front - 1.2), PI * 0.5)

func _add_stall(ctx: Dictionary, dx: float) -> void:
	var x: float = ctx["x0"] + dx
	var stall := HouseProps.stall()
	stall.add_child(_one_shots(HAMMER_SFX, 10.0, 28.0, 8.0, 17.0, Vector3(0, 1.2, -0.4)))   # the shopkeeper mending crates
	_put(ctx, stall, Vector3(x, float(ctx["floor"]), _wall(ctx, ctx["x0"]) + STALL_OUT))

func _one_shots(paths: Array, min_gap: float, max_gap: float, from_hour: float, to_hour: float, pos: Vector3) -> SpatialOneShots:
	var shots := SpatialOneShots.new()
	shots.name = "OneShots"
	shots.position = pos
	var list: Array[AudioStream] = []
	for path in paths:
		if not Engine.is_editor_hint():   # nothing plays in the editor, so don't load there
			var stream := load(path) as AudioStream
			if stream != null:
				list.append(stream)
	shots.streams = list
	shots.min_gap = min_gap
	shots.max_gap = max_gap
	shots.active_from = from_hour
	shots.active_to = to_hour
	return shots

func _add_barrels(ctx: Dictionary, dx: float) -> void:
	var x: float = ctx["x0"] + dx
	_put(ctx, HouseProps.crates_and_barrels(), Vector3(x, float(ctx["floor"]), _wall(ctx, x) + 0.55))

func _add_chimes(ctx: Dictionary, side: float) -> void:
	var x: float = ctx["x0"] + side * (LANTERN_X + 0.15)
	_put(ctx, HouseProps.wind_chimes(), Vector3(x, float(ctx["floor"]) + CHIMES_HEIGHT, _wall(ctx, x) - WALL_SINK))

func _add_notice_board(ctx: Dictionary) -> void:
	var x: float = ctx["x0"] + NOTICE_X
	var notes := [
		{"text": "LOST CAT\nBiscuit, ginger\nAsk at Vael's", "hide_when": "cat_found"},
		{"text": "BISCUIT IS\nHOME!\nThank you!", "show_when": ["cat_found"]},
		{"text": "BALL LOST\nDOWN THE WELL\n- Yule", "hide_when": "yule_got_ball"},
		{"text": "PACK STUCK\nON A LEDGE\n- Brant", "hide_when": "brant_got_pack"},
	]
	_put(ctx, HouseProps.notice_board(notes), Vector3(x, float(ctx["floor"]), _wall(ctx, ctx["x0"]) + NOTICE_OUT))

# ------------------------------------------------------------------ animals

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

func _add_perches(ctx: Dictionary) -> void:
	var points := _ridge_points(ctx["house"])
	for i in mini(points.size(), 2):
		var marker := Marker3D.new()
		marker.name = "BirdPerch%d" % i
		marker.add_to_group(&"bird_perch")
		_put(ctx, marker, points[i])

func _add_cat(ctx: Dictionary) -> void:
	var points := _ridge_points(ctx["house"])
	if points.is_empty():
		return
	var cat := RoofCat.new()
	cat.name = "RoofCat"
	_put(ctx, cat, points.back(), PI)   # the cat faces -Z; turn it to watch the street

func _add_chickens(ctx: Dictionary, dx: float) -> void:
	var x: float = ctx["x0"] + dx
	var hens := Chickens.new()
	hens.name = "Chickens"
	_put(ctx, hens, Vector3(x, float(ctx["floor"]), _wall(ctx, ctx["x0"]) + 3.6))
