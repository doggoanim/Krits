@tool
class_name Gatherable
extends Interactable
## Something to pick up from the ground or wall: a clump of cave moss, a glowing shard, a pile
## of old coins, a tuft of spider silk. Press interact to take it (one `item_id`, 1..`max_count`).
## It grows back after `respawn_hours` of game time (WorldClock), so it is a source but not a
## faucet.

enum Kind { MOSS, CRYSTAL, COINS, WEB }

const ITEM := {Kind.MOSS: &"cave_moss", Kind.CRYSTAL: &"glow_shard", Kind.COINS: &"old_coin", Kind.WEB: &"spider_silk"}
const VERB := {Kind.MOSS: "Press E to pick", Kind.CRYSTAL: "Press E to chip off", Kind.COINS: "Press E to take", Kind.WEB: "Press E to collect"}

@export var kind := Kind.MOSS:
	set(v):
		kind = v
		_rebuild()
@export var max_count := 2
@export var respawn_hours := 18
@export var snap_to_ground := true

var _visual: Node3D
var _hours_left := 0

func _init() -> void:
	collision_layer = 0
	collision_mask = 0
	interact_radius = 1.5
	prompt_height = 0.7

func _ready() -> void:
	prompt_text = VERB[kind]
	super()
	_rebuild()
	if Engine.is_editor_hint():
		return
	WorldClock.hour_changed.connect(_on_hour)
	if snap_to_ground:
		_snap()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = match_visual()
	_visual.name = "Visual"
	add_child(_visual)
	prompt_text = VERB[kind]

func match_visual() -> Node3D:
	match kind:
		Kind.CRYSTAL: return PlayProps.crystal_shard()
		Kind.COINS: return PlayProps.coin_pile()
		Kind.WEB: return PlayProps.web_clump()
		_: return PlayProps.moss_clump()

func _snap() -> void:
	await get_tree().physics_frame
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.DOWN * 4.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y

func _can_interact() -> bool:
	return (_hours_left <= 0 and player != null and not player.dead and not Game.in_combat
		and player.machine.current_name == &"Ground" and MenuBase.open_menu == null)

func _interact() -> void:
	var item: StringName = ITEM[kind]
	var n := randi_range(1, maxi(1, max_count))
	ItemGet.give(item, n)
	var data := ItemLibrary.by_id(item)
	Events.notice.emit("Found %dx %s" % [n, data.display_name if data != null else String(item)])
	PropSfx.play_at(self, PropSfx.SQUEAK, global_position, Vector2(1.6, 2.0), -8.0)
	player.visual.squash_stretch(0.88, 1.08)
	_hours_left = respawn_hours
	_visual.visible = false

func _on_hour(_hour: int) -> void:
	if _hours_left <= 0:
		return
	_hours_left -= 1
	if _hours_left <= 0:
		_visual.visible = true
