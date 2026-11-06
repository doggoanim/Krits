class_name Chest
extends Interactable
## A treasure chest. Interact to open it: the lid swings up (Opening clip +
## sound), the chest then STAYS open until the player walks `close_distance`
## away, when it closes by itself (Closing clip + sound).
##
## Chests are mostly one-time: the first opening hands over `loot_id` through
## ItemGet (so gear and important items get the full held-up "You got the ..."
## fanfare, and the game saves afterwards). The chest remembers it was looted in
## a story flag, so after that it still opens and closes like normal but
## only says it's empty.
##
## Placing one: instance world/chest.tscn, give it a unique `chest_id` and a
## `loot_id` — an equipment id (EquipmentLibrary) or an item id (ItemLibrary).
## Its collision box is built automatically; rotate the node so +Z (the
## front) faces where the player will come from.

const MODEL: PackedScene = preload("res://assets/world/chest.glb")
const SFX_OPEN_PATH := "res://sounds/SFX/chest_opening.wav"
const SFX_CLOSE_PATH := "res://sounds/SFX/chest_closing.wav"

const ANIM_OPENING := &"Opening"
const ANIM_OPEN_IDLE := &"Open_Idle"
const ANIM_CLOSING := &"Closing"
const ANIM_CLOSE_IDLE := &"Close_Idle"

const BODY_SIZE := Vector3(1.1, 0.8, 0.7)   ## closed chest, for the collision box
const FALLBACK_ANIM_TIME := 0.7             ## used when the model has no animations

enum State { CLOSED, OPENING, OPEN, CLOSING }

## Unique per chest; "chest_<chest_id>" is the flag that remembers it was looted.
@export var chest_id: StringName = &""
## What's inside: an EquipmentLibrary id (wooden_sword...) or an ItemLibrary id.
@export var loot_id: StringName = &""
@export var loot_count := 1
## It closes by itself once the player is farther than this (keep it larger than
## interact_radius so it doesn't flicker at the edge).
@export var close_distance := 6.0
## Drop the chest onto the floor below it when the level loads, so placing it
## roughly in the editor is enough.
@export var snap_to_ground := true
@export var empty_text := "It's empty."

var _state := State.CLOSED
var _anim: AnimationPlayer
var _sfx_open: AudioStream
var _sfx_close: AudioStream

func _init() -> void:
	prompt_text = "Press E to open"
	prompt_height = 1.3
	interact_radius = 2.0

func _ready() -> void:
	super()
	_build_model()
	_ensure_collision()
	if ResourceLoader.exists(SFX_OPEN_PATH):
		_sfx_open = load(SFX_OPEN_PATH)
	if ResourceLoader.exists(SFX_CLOSE_PATH):
		_sfx_close = load(SFX_CLOSE_PATH)
	if snap_to_ground:
		_snap_to_ground()

func _flag() -> StringName:
	return StringName("chest_" + String(chest_id))

func is_looted() -> bool:
	return Game.flag(_flag())

# --- Interaction -------------------------------------------------------------

func _can_interact() -> bool:
	return _state == State.CLOSED and player != null and not player.dead \
			and not Game.input_locked and player.machine.current_name == &"Ground"

func _interact() -> void:
	_open()

func _process(delta: float) -> void:
	super(delta)
	if _state == State.OPEN and _player_is_far():
		_close()

func _player_is_far() -> bool:
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	return p == null or global_position.distance_to(p.global_position) > close_distance

# --- Open / close ------------------------------------------------------------

func _open() -> void:
	_state = State.OPENING
	_play_sfx(_sfx_open)
	await _play_and_wait(ANIM_OPENING)
	_state = State.OPEN
	_play(ANIM_OPEN_IDLE)
	_give_loot()

func _close() -> void:
	_state = State.CLOSING
	_play_sfx(_sfx_close)
	await _play_and_wait(ANIM_CLOSING)
	_state = State.CLOSED
	_play(ANIM_CLOSE_IDLE)

func _give_loot() -> void:
	if loot_id == &"" or is_looted():
		Events.notice.emit(empty_text)
		return
	var gear := EquipmentLibrary.by_id(loot_id)
	if gear == null and ItemLibrary.by_id(loot_id) == null:
		push_warning("Chest '%s': unknown loot_id '%s'" % [chest_id, loot_id])
		Events.notice.emit(empty_text)
		return
	# The flag is set now (so it can't be looted twice) but only saved once the
	# item is actually in the player's hands — ItemGet runs `Game.save` then.
	Game.set_flag(_flag())
	if gear != null:
		ItemGet.give_gear(gear, Game.save)
	else:
		ItemGet.give(loot_id, loot_count, Game.save)

# --- Pieces ------------------------------------------------------------------

func _build_model() -> void:
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0] as AnimationPlayer
		# The transitions play once; the idles are single poses.
		for clip in [ANIM_OPENING, ANIM_CLOSING]:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE
	_play(ANIM_CLOSE_IDLE)

## A collision box so the player can't walk through it, unless the scene already
## provides a CollisionShape3D of its own.
func _ensure_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, BODY_SIZE.y * 0.5, 0.0)
	add_child(shape)

func _play(clip: StringName) -> void:
	if _anim != null and _anim.has_animation(clip):
		_anim.play(clip)

## Plays `clip` and waits for it to end (or a fixed beat if the model lacks it).
func _play_and_wait(clip: StringName) -> void:
	if _anim != null and _anim.has_animation(clip):
		_anim.play(clip)
		await _anim.animation_finished
	else:
		await get_tree().create_timer(FALLBACK_ANIM_TIME).timeout

func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = &"SFX"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _snap_to_ground() -> void:
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 0.6, global_position + Vector3.DOWN * 6.0, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = hit.position.y
