class_name QuestProp
extends NPC
## Something in the world that belongs to a quest: a clue to find, a missing
## pet, a stolen bun. It is an NPC (talk to it with the interact key, its lines
## come from a .dlg — see dialogue/dialogue_parser.gd), plus:
##   - `show_when`: it only exists once ALL of these story flags are set (a clue
##     appears once the quest is accepted; the cat once every clue is found)
##   - `hide_when`: it vanishes once this flag is set (after the current
##     conversation ends, so a pick-up line isn't cut off)
##   - `done_flag`: its floating marker goes away once this flag is set
##   - a built-in placeholder look per `kind` (QuestPropVisuals), or give it a
##     `model` like any NPC
##   - it drops onto the ground below where you place it
## Not solid: the player walks through it, so a clue never blocks a path.

enum Kind { NONE, FUR_TUFT, PAW_PRINTS, BUN, CAT }

@export var kind := Kind.NONE
@export var show_when: Array[StringName] = []
@export var hide_when: StringName = &""
@export var done_flag: StringName = &""
@export var snap_to_ground := true

const MARKER_BOB := 0.07
const MARKER_SPIN := 1.6
const SNAP_UP := 3.0
const SNAP_DOWN := 8.0
const WORLD_LAYER := 1
const IDLE_BREATH := 0.02

var _visual: Node3D
var _marker: Node3D
var _marker_base_y := 0.0
var _t := 0.0

func _init() -> void:
	collision_layer = 0
	collision_mask = 0
	interact_radius = 1.8
	prompt_height = 0.9

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	face_player = kind == Kind.CAT
	head_height = 0.6 if kind == Kind.CAT else 0.3
	if model == null and kind != Kind.NONE:
		_visual = QuestPropVisuals.build(kind)
		add_child(_visual)
		_marker = _visual.get_node_or_null(QuestPropVisuals.MARKER_NAME) as Node3D
		if _marker != null:
			_marker_base_y = _marker.position.y
	_refresh()
	if snap_to_ground:
		_snap_to_ground()

func _process(delta: float) -> void:
	super(delta)
	_t += delta
	_refresh()
	if _marker != null and _marker.visible:
		_marker.position.y = _marker_base_y + sin(_t * 2.2) * MARKER_BOB
		_marker.rotation.y += delta * MARKER_SPIN
	if kind == Kind.CAT and _visual != null:
		_visual.scale.y = 1.0 + sin(_t * 2.0) * IDLE_BREATH   # slow breathing

func _can_interact() -> bool:
	return visible and super()

func _refresh() -> void:
	var talking := DialogueBox.instance != null and DialogueBox.instance.is_active()
	var shown := true
	for f in show_when:
		if not Game.flag(f):
			shown = false
	if hide_when != &"" and Game.flag(hide_when) and not talking:
		shown = false
	visible = shown
	if _marker != null:
		_marker.visible = done_flag == &"" or not Game.flag(done_flag)

func _snap_to_ground() -> void:
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * SNAP_UP, global_position + Vector3.DOWN * SNAP_DOWN, WORLD_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = hit.position.y
