@tool
class_name RegionGate
extends Area3D
## A walk-through entrance between regions of the open world, Ocarina-of-Time
## style: no button press — step into the gap and the screen irises over to
## `target_level`, putting you at that level's spawn `target_spawn_id`. Doors
## (world/door.gd) stay for buildings; gates are for the open-air seams.
##
## `target_level` is a path string for the same reason Door's is (two scenes
## that gate into each other would otherwise form a circular resource
## dependency). An empty target makes a sealed gate: it just says the way is
## blocked, which lets a region be laid out before its neighbour exists.

@export_file("*.tscn") var target_level := ""
@export var target_spawn_id: StringName = &"start"
@export var required_flag: StringName = &""
@export var blocked_text := "The way ahead is blocked."
@export var width := 6.0:
	set(v):
		width = v
		_rebuild()
@export var height := 5.0:
	set(v):
		height = v
		_rebuild()

const NOTICE_COOLDOWN := 3.0
var _notice_left := 0.0
var _used := false
var _shape := CollisionShape3D.new()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1   # the player, same as Spawnpoint
	add_child(_shape)
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_notice_left = maxf(0.0, _notice_left - delta)

func _rebuild() -> void:
	if _shape == null:
		return
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 1.5)
	_shape.shape = box
	_shape.position.y = height * 0.5

func _on_body_entered(body: Node3D) -> void:
	if not body is Player or _used or Game.input_locked or Game.in_combat:
		return
	if target_level.is_empty() or (required_flag != &"" and not Game.flag(required_flag)):
		if _notice_left <= 0.0:
			_notice_left = NOTICE_COOLDOWN
			Events.notice.emit(blocked_text)
		return
	_used = true
	Events.level_travel_requested.emit(load(target_level) as PackedScene, target_spawn_id)
	get_tree().create_timer(2.0).timeout.connect(func() -> void: _used = false)
