class_name Spawnpoint
extends Area3D
## Checkpoint + fast-travel node. Touch it once to unlock; it heals and saves.

@export var spawn_id: StringName = &"start"
@export var display_name := "Start"
@export var region_name := ""   ## small subtitle on the fast travel card (optional)

const LABEL_HEIGHT := 3.6
const LABEL_LOCKED_ALPHA := 0.5
const TRIGGER_RADIUS := 1.6
const TRIGGER_HEIGHT := 3.0

var _crystal: CheckpointCrystal
var _label: Label3D
var _player_inside := false   ## the player is standing in this point's area right now

## The spawnpoint the player is currently standing at, or null. Fast travel is
## only allowed from one (see TravelMenu.can_open()).
static func occupied(tree: SceneTree) -> Spawnpoint:
	for n in tree.get_nodes_in_group(&"spawnpoints"):
		var sp := n as Spawnpoint
		if sp != null and sp._player_inside:
			return sp
	return null

func _ready() -> void:
	add_to_group(&"spawnpoints")
	collision_layer = 1 << 5
	collision_mask = 1 << 1
	_build_trigger()
	_crystal = CheckpointCrystal.new()
	add_child(_crystal)
	_build_label()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Events.spawnpoint_activated.connect(func(_id): _refresh())
	_crystal.set_unlocked(is_unlocked(), false)
	_refresh(false)

func is_unlocked() -> bool:
	return spawn_id in Game.unlocked_spawns

func activate() -> void:
	Game.unlock_spawn(spawn_id)
	Game.stats.full_heal()

func respawn_position() -> Vector3:
	return global_position + Vector3.UP * 0.2

func _build_trigger() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = TRIGGER_RADIUS
	shape.height = TRIGGER_HEIGHT
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = TRIGGER_HEIGHT * 0.5
	add_child(cs)

func _build_label() -> void:
	_label = Label3D.new()
	_label.text = display_name
	_label.position.y = LABEL_HEIGHT
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 56
	_label.pixel_size = 0.006
	_label.outline_size = 12
	_label.outline_modulate = Color(0.02, 0.05, 0.1, 0.9)
	add_child(_label)

func _on_body_entered(b: Node3D) -> void:
	if not b is Player:
		return
	_player_inside = true
	_crystal.set_active(true)
	var first := not is_unlocked()
	activate()
	_crystal.flash(1.0 if first else 0.35)

func _on_body_exited(b: Node3D) -> void:
	if b is Player:
		_player_inside = false
		_crystal.set_active(false)

func _refresh(animate := true) -> void:
	_crystal.set_unlocked(is_unlocked(), animate)
	var tint := CheckpointCrystal.UNLOCKED_COLOR if is_unlocked() else Color.WHITE
	_label.modulate = Color(tint, 1.0 if is_unlocked() else LABEL_LOCKED_ALPHA)
