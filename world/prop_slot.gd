@tool
class_name PropSlot
extends Node3D
## One everyday prop on a house (a lantern, bunting, a stall, a cat...). HouseExtras
## creates these the first time and — in the editor — makes them real, saved nodes: select
## one in the scene tree and MOVE, ROTATE or DELETE it like anything else, or duplicate it
## (Ctrl+D) for another. The slot only stores where it is and what kind it is; the
## meshes underneath are rebuilt from `kind` every time the scene loads and are never saved,
## so moving a prop never bloats the scene.
##
## Change `kind` / `length` in the Inspector and it rebuilds itself on the spot.

enum Kind {   # explicit numbers: scenes store the number, so removed kinds leave a gap rather than renumbering the rest
	LANTERN = 1, BUNTING, LAUNDRY_LINE, WOOD_PILE, STALL, CRATES_AND_BARRELS,
	WIND_CHIMES, NOTICE_BOARD, CHICKENS, BIRD_PERCH = 11, BUCKET, BONE_PILE,
}

@export var kind := Kind.LANTERN:
	set(v):
		kind = v
		_rebuild()
@export_range(0.5, 12.0, 0.1) var length := 4.0:   ## bunting / laundry line: how long it is (m)
	set(v):
		length = v
		_rebuild()
@export_tool_button("Rebuild") var rebuild_button := _rebuild

const VISUAL := "Visual"
const PERCH_GROUP := &"bird_perch"
const HAMMER_SFX := ["res://sounds/SFX/others/hammer_tink.ogg"]
const CHOP_SFX := ["res://sounds/SFX/others/wood_chop.ogg"]

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	var old := get_node_or_null(VISUAL)
	if old != null:
		remove_child(old)
		old.queue_free()
	if kind == Kind.BIRD_PERCH:
		add_to_group(PERCH_GROUP)
	else:
		remove_from_group(PERCH_GROUP)
	var visual := _make()
	if visual == null:
		return
	visual.name = VISUAL   # no owner: rebuilt on load, never saved
	add_child(visual)

func _make() -> Node3D:
	match kind:
		Kind.LANTERN:
			return HouseProps.lantern()
		Kind.BUNTING:
			return HouseProps.bunting(length, maxi(int(length / 0.45), 4))
		Kind.LAUNDRY_LINE:
			return HouseProps.laundry_line(length, maxi(int(length / 0.85), 2))
		Kind.WOOD_PILE:
			var pile := HouseProps.wood_pile()
			_add_one_shots(pile, CHOP_SFX, 14.0, 40.0, 7.0, 18.5, Vector3(1.9, 0.8, 0.5))   # someone splitting logs by day
			return pile
		Kind.STALL:
			var stall := HouseProps.stall()
			_add_one_shots(stall, HAMMER_SFX, 10.0, 28.0, 8.0, 17.0, Vector3(0, 1.2, -0.4))   # the shopkeeper mending crates
			return stall
		Kind.CRATES_AND_BARRELS:
			return HouseProps.crates_and_barrels()
		Kind.WIND_CHIMES:
			return HouseProps.wind_chimes()
		Kind.NOTICE_BOARD:
			return HouseProps.notice_board(NOTICES)
		Kind.BUCKET:
			return HouseProps.bucket()
		Kind.BONE_PILE:
			return HouseProps.bone_pile()
		Kind.CHICKENS:
			return Chickens.new()
		Kind.BIRD_PERCH:
			if Engine.is_editor_hint():   # a little bird so the perch can be seen and picked in the editor
				return CritterParts.bird(Color(0.55, 0.4, 0.28), Color(0.85, 0.7, 0.55))["root"]
	return null

## Notes pinned on a notice board, by story flag (see HouseProps.notice_board).
const NOTICES := [
	{"text": "LOST CAT\nBiscuit, ginger\nAsk at Vael's", "hide_when": "cat_found"},
	{"text": "BISCUIT IS\nHOME!\nThank you!", "show_when": ["cat_found"]},
	{"text": "BALL LOST\nDOWN THE WELL\n- Yule", "hide_when": "yule_got_ball"},
	{"text": "PACK STUCK\nON A LEDGE\n- Henry", "hide_when": "henry_got_pack"},
]

## Occasional sounds from a prop (never in the editor, where nothing plays).
func _add_one_shots(parent: Node3D, paths: Array, min_gap: float, max_gap: float, from_hour: float, to_hour: float, pos: Vector3) -> void:
	if Engine.is_editor_hint():
		return
	var shots := SpatialOneShots.new()
	shots.name = "OneShots"
	shots.position = pos
	var list: Array[AudioStream] = []
	for path in paths:
		var stream := load(path) as AudioStream
		if stream != null:
			list.append(stream)
	shots.streams = list
	shots.min_gap = min_gap
	shots.max_gap = max_gap
	shots.active_from = from_hour
	shots.active_to = to_hour
	parent.add_child(shots)
