class_name HeldItem
extends Node
## "Hold up" for fish: the player strikes the item-get pose (Getting_Item, arms
## raised) with the fish floating over their head — only the animation, no
## fanfare, no text, nothing is used up. Unlike ItemGet the player isn't frozen:
## moving, jumping, getting hit or starting a fight puts the fish back.
##
## Opened from the bag's "Hold up" button (Inventory.use() → HeldItem.start()).
## One instance lives under UiRoot (HeldItem.instance).

static var instance: HeldItem

const GRACE := 0.35             ## seconds after starting before input can cancel (the click that started it)
const MOVE_DEADZONE := 0.2
const PROP_RAISE := 0.3         ## metres above the head the fish's centre floats (plus half its height)
const MAX_VISUAL_LENGTH := 4.0  ## a colossal fish is drawn at most this long, so it stays on screen
const BOB := 0.04
const SWAY := 0.5               ## radians of slow side-to-side turn
const POP_TIME := 0.35

var _player: Player
var _prop: Node3D
var _age := 0.0
var _length := 0.4

func _ready() -> void:
	instance = self
	set_process(false)

func _exit_tree() -> void:
	if instance == self:
		instance = null
	_put_back()

static func is_holding() -> bool:
	return instance != null and instance._prop != null

## Starts holding up `item` at `size` (see FishCatalog). Returns "" or why not.
static func start(item: ItemData, size: float) -> String:
	if instance == null:
		return "Can't hold that up here."
	return instance._start(item, size)

## Puts it back right now (no-op when nothing is held).
static func stop() -> void:
	if instance != null:
		instance._put_back()

func _start(item: ItemData, size: float) -> String:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.dead or Game.in_combat or player.machine.current_name != &"Ground":
		return "Can't do that right now."
	if ItemGet.instance != null and ItemGet.instance.is_playing():
		return "Can't do that right now."
	_put_back()
	_player = player
	_length = minf(FishCatalog.length_of(item.id, size), MAX_VISUAL_LENGTH)
	_face_camera()
	_player.visual.play_hold(PlayerVisual.ANIM_GET_ITEM, 600.0, 1.0, false, 0.1)
	_player.visual.hold_expression(&"happy")
	_spawn_prop(item)
	if not Events.player_hurt.is_connected(_on_hurt):
		Events.player_hurt.connect(_on_hurt)
	_age = 0.0
	set_process(true)
	return ""

func _spawn_prop(item: ItemData) -> void:
	_prop = Node3D.new()
	var fish := FishModel.build(item.id, item.color)
	fish.scale = Vector3.ONE * _length
	_prop.add_child(fish)
	_player.add_child(_prop)
	_place_prop()
	var pop := _prop.scale
	_prop.scale = Vector3.ZERO
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(_prop, "scale", pop, POP_TIME)

func _place_prop() -> void:
	_prop.position.y = Player.STAND_HEIGHT + PROP_RAISE + _length * 0.2 + sin(_age * 2.4) * BOB
	_prop.rotation.y = sin(_age * 1.3) * SWAY
	_prop.rotation.z = sin(_age * 3.1) * 0.06   # a little wriggle

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _prop == null:
		_put_back()
		return
	_age += delta
	_place_prop()
	if _should_put_back():
		_put_back()

func _should_put_back() -> bool:
	if _player.dead or Game.in_combat or _player.machine.current_name != &"Ground":
		return true
	if DialogueBox.instance != null and DialogueBox.instance.is_active():
		return true
	if _age < GRACE:
		return false
	if Input.is_action_just_pressed(&"jump"):
		return true
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back").length() > MOVE_DEADZONE

func _on_hurt(_from: Vector3) -> void:
	_put_back()

func _face_camera() -> void:
	var rig := _player.camera_rig
	var cam: Camera3D = rig.get_camera() if rig != null else null
	if cam != null:
		_player.face(cam.global_position - _player.global_position)

func _put_back() -> void:
	set_process(false)
	if Events.player_hurt.is_connected(_on_hurt):
		Events.player_hurt.disconnect(_on_hurt)
	if is_instance_valid(_player):
		_player.visual.cancel_hold()
		_player.visual.release_expression()
	if is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null
	_player = null
