@tool
class_name HouseDressing
extends Node
## Makes the identical Chesburg houses look different without touching their colours:
## chimneys (count and style vary, some smoke), a dormer window or a weathervane on
## some roofs, and a door awning / porch / step on some entrances. (House sizes and
## heights are set by each house's scale in the scene.)
##
## Everything stands on the roof or wall wherever the house is, found from the model's own
## triangles (RoofProbe). It runs in the editor too, but the parts are children without an
## owner, so they show in the scene view and are never saved into the scene.
##
## Per-house choices are the arrays below, in the order the houses appear under the parent.
## Edit them (or `seed_offset`) to reshuffle.

const CHIMNEYS: Array[int] = [1, 1, 2, 1, 1, 2]                       ## how many chimneys
const CHIMNEY_STYLES: Array[int] = [0, 2, 1, 3, 0, 2]                 ## HouseParts.ChimneyStyle
const CHIMNEY_SIZES: Array[Vector2] = [                               ## (width, height)
	Vector2(0.75, 1.7), Vector2(0.9, 1.4), Vector2(0.7, 2.0),
	Vector2(0.8, 1.6), Vector2(0.7, 1.5), Vector2(0.85, 1.9),
]
const CHIMNEY_SPOTS: Array[Vector2] = [                               ## where one may stand (x, z)
	Vector2(-1.9, -0.9), Vector2(1.8, -0.5), Vector2(0.0, 0.6),
	Vector2(1.6, 0.8), Vector2(-1.2, -0.5), Vector2(-2.0, 0.7),
]
const DORMERS: Array[bool] = [true, false, true, false, false, true]
const WEATHERVANES: Array[bool] = [false, true, true, false, true, false]
## HouseParts.AwningStyle per house, or -1 for a bare door.
const ENTRANCES: Array[int] = [0, 1, 2, -1, -1, 0]
const WOOD_SHADES: Array[float] = [0.1, 0.6, 0.3, 0.0, 0.0, 0.9]

const CHIMNEY_SINK := 0.5       ## how far a chimney's base is buried in the roof
const DORMER_SINK := 0.3
const VANE_SINK := 0.1
const CLEARANCE := 1.5          ## roof parts keep this far apart (metres)
const DOOR_WALL_OFFSET := 0.33  ## from a Door_* node to the wall face in front of it
const DOOR_FLOOR_DROP := 1.0    ## a Door_* node sits this far above the floor
const MAX_DOOR_SETBACK := 1.0   ## a door deeper than this behind the footprint isn't dressed (the mayor's)
const WALL_OVERLAP := 0.3       ## the entrance sinks this far into the wall: no gap, and it hugs the door
const SIGN_HEIGHT := 4.2         ## the rod's height above the door's floor (the board hangs below it, clear of the awning)
const META := &"house_dressing"

## Houses to dress: nodes in the parent whose name contains one of these.
@export var name_filter: PackedStringArray = ["house_chesburg"]
## Shifts which choices each house gets; change it to reshuffle.
@export var seed_offset := 0
## Name signs hung above a house's door: house node name -> text. (Constants, not exports:
## an exported list gets frozen into the saved scene the first time the editor saves it, so
## later changes here would silently not apply.)
const SIGNS := {
	"house_chesburg_1": "Krits", "house_chesburg_3": "Myr. Arse", "house_chesburg_6": "Shop",
	"house_chesburg_2": "Tuppence", "house_chesburg_4": "Bakery", "house_chesburg_5": "Yule",
}
## Houses whose sign is a tall vertical board (letters stacked), and how far it hangs from
## the door sideways (metres; + is the viewer's right when facing the house).
const VERTICAL_SIGNS: Array[String] = ["house_chesburg_2"]
const SIGN_OFFSETS := {"house_chesburg_2": 1.8}
## Size of a house's sign (house node name -> scale; 1 if absent).
const SIGN_SCALES := {"house_chesburg_3": 0.65}
## Rod height above the door's floor per house (SIGN_HEIGHT if absent); houses without an awning hang lower.
const SIGN_HEIGHTS := {"house_chesburg_3": 3.2, "house_chesburg_6": 3.6, "house_chesburg_2": 4.0}
## Chimneys puff smoke.
@export var chimney_smoke := true

## Click in the inspector to rebuild everything (e.g. after changing the lists below).
@export_tool_button("Rebuild dressing") var rebuild_button := _dress_all

func _ready() -> void:
	# Deferred: in the editor the scene is still being assembled during _ready, so the
	# houses' meshes and doors may not be in place yet.
	_dress_all.call_deferred()

func _dress_all() -> void:
	var holder := get_parent()
	if holder == null or not is_inside_tree():
		return
	var index := 0
	var signed := 0
	for child in holder.get_children():
		if child is Node3D and _matches(child.name):
			_dress(child as Node3D, index + seed_offset)
			if SIGNS.has(String(child.name)):
				signed += 1
			index += 1
	if Engine.is_editor_hint():
		print("HouseDressing: dressed %d houses (%d signs)" % [index, signed])

func _matches(node_name: String) -> bool:
	for f in name_filter:
		if node_name.containsn(f):
			return true
	return false

func _dress(house: Node3D, index: int) -> void:
	_clear(house)   # re-running (the editor reloading the script) must not stack parts
	var front := _front_z(house)   # measured before any part is added
	var taken: Array[Vector2] = []
	if WEATHERVANES[index % WEATHERVANES.size()]:
		_add_weathervane(house, taken)
	_add_chimneys(house, index, taken)
	if DORMERS[index % DORMERS.size()]:
		_add_dormer(house, index, taken)
	if SIGNS.has(String(house.name)):
		_add_sign(house, String(SIGNS[String(house.name)]))
	var style: int = ENTRANCES[index % ENTRANCES.size()]
	if style >= 0:
		_add_entrance(house, front, style, WOOD_SHADES[index % WOOD_SHADES.size()])

func _clear(house: Node3D) -> void:
	for child in house.get_children():
		if child.has_meta(META):
			house.remove_child(child)
			child.queue_free()

## Adds `part` to the house (no owner: editor-only, never saved), undoing the house's own
## scale so a squashed or stretched house doesn't squash its chimney.
func _place(house: Node3D, part: Node3D, pos: Vector3, yaw := 0.0, extra_scale := 1.0) -> void:
	part.set_meta(META, true)
	part.position = pos
	part.rotation.y = yaw
	var s := house.basis.get_scale()
	part.scale = Vector3(1.0 / maxf(s.x, 0.01), 1.0 / maxf(s.y, 0.01), 1.0 / maxf(s.z, 0.01)) * extra_scale
	house.add_child(part)

func _free_spot(taken: Array[Vector2], xz: Vector2) -> bool:
	for t in taken:
		if t.distance_to(xz) < CLEARANCE:
			return false
	return true

# ------------------------------------------------------------------- roof

func _add_chimneys(house: Node3D, index: int, taken: Array[Vector2]) -> void:
	var wanted: int = CHIMNEYS[index % CHIMNEYS.size()]
	var size := CHIMNEY_SIZES[index % CHIMNEY_SIZES.size()]
	var style: int = CHIMNEY_STYLES[index % CHIMNEY_STYLES.size()]
	var made := 0
	for k in CHIMNEY_SPOTS.size():
		if made >= wanted:
			return
		var xz := CHIMNEY_SPOTS[(index + k) % CHIMNEY_SPOTS.size()]
		if not _free_spot(taken, xz):
			continue
		var roof := RoofProbe.sample(house, xz)
		if roof.is_empty():
			continue
		# the second chimney is a little slimmer and a different style
		var this_style := style if made == 0 else (style + 1) % HouseParts.STYLE_COUNT
		var width := size.x if made == 0 else size.x * 0.8
		var chimney := HouseParts.chimney(this_style, width, size.y, chimney_smoke and made == 0)
		_place(house, chimney, Vector3(xz.x, float(roof["y"]) - CHIMNEY_SINK, xz.y))
		taken.append(xz)
		made += 1

func _add_dormer(house: Node3D, index: int, taken: Array[Vector2]) -> void:
	var side := 1.0 if index % 2 == 0 else -1.0
	for dz in [0.5, 1.0, 1.5, 0.0, 2.0]:
		for dx in [1.6, 2.2, 1.0]:
			var xz := Vector2(side * dx, dz)
			if not _free_spot(taken, xz):
				continue
			var roof := RoofProbe.sample(house, xz)
			if roof.is_empty():
				continue
			var n: Vector3 = roof["normal"]
			if n.z < 0.3 or n.y < 0.2 or n.y > 0.9:   # must be a slope facing the front
				continue
			_place(house, HouseParts.dormer(), Vector3(xz.x, float(roof["y"]) - DORMER_SINK, xz.y), atan2(n.x, n.z))
			taken.append(xz)
			return

func _add_weathervane(house: Node3D, taken: Array[Vector2]) -> void:
	var top := RoofProbe.ridge(house, Vector2.ZERO)
	if top.is_empty():
		return
	var xz := Vector2(float(top["x"]), float(top["z"]))
	_place(house, HouseParts.weathervane(), Vector3(xz.x, float(top["y"]) - VANE_SINK, xz.y))
	taken.append(xz)

# --------------------------------------------------------------- entrance

func _add_entrance(house: Node3D, front: float, style: int, shade: float) -> void:
	var x := 0.0
	var wall := front
	var floor_y := 0.0
	var door := _door_of(house)
	if door != null:
		if front - door.position.z > MAX_DOOR_SETBACK:
			return
		x = door.position.x
		wall = door.position.z + DOOR_WALL_OFFSET
		floor_y = door.position.y - DOOR_FLOOR_DROP
	var flush := RoofProbe.wall_front(house, x)   # the real wall face, not the eaves or the door node
	if not is_nan(flush):
		wall = flush
	_place(house, HouseParts.entrance(style, shade), Vector3(x, floor_y, wall - WALL_OVERLAP))

## A hanging sign above the house's door (Door_* node), flush on the wall there.
func _add_sign(house: Node3D, text: String) -> void:
	var door := _door_of(house)
	if door == null:
		push_warning("HouseDressing: %s has no Door_* child, so it gets no sign" % house.name)
		return
	var floor_y := door.position.y - DOOR_FLOOR_DROP
	# the same wall face (and the same sink into it) as the door entrance, so both sit at one distance
	var x := door.position.x + float(SIGN_OFFSETS.get(String(house.name), 0.0))
	var wall := RoofProbe.wall_front(house, x, 1.5, floor_y + 0.3, floor_y + 2.5)
	if is_nan(wall):
		wall = door.position.z + DOOR_WALL_OFFSET
	_place(house, HouseParts.hanging_sign(text, VERTICAL_SIGNS.has(String(house.name))), Vector3(x, floor_y + float(SIGN_HEIGHTS.get(String(house.name), SIGN_HEIGHT)), wall - WALL_OVERLAP),
			0.0, float(SIGN_SCALES.get(String(house.name), 1.0)))

func _door_of(house: Node3D) -> Node3D:
	for child in house.get_children():
		if child is Node3D and String(child.name).begins_with("Door_"):
			return child as Node3D
	return null

## The front (+Z) edge of the house's visible meshes, in the house's own space.
func _front_z(house: Node3D) -> float:
	var inverse := house.global_transform.affine_inverse()
	var front := -INF
	for m in house.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or String(mi.name).containsn(RoofProbe.COLLISION_NAME):
			continue
		var box := (inverse * mi.global_transform) * mi.mesh.get_aabb()
		front = maxf(front, box.end.z)
	return front if front > -INF else 0.0
