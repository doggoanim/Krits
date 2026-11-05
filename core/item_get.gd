class_name ItemGet
extends Node
## The Zelda-style "item get" moment for important items (ItemData.important):
## the player freezes, turns straight to face the camera, strikes the
## Getting_Item pose with the treasure floating above their head, the jingle
## plays (music ducks), and the dialogue box opens with no speaker, just
## "You got the <item>!" — advance/close it like any other dialogue. The item
## lands in the bag when that box closes.
##
## Everything that hands the player an item should go through ItemGet.give():
## ordinary items are added to the bag at once, important ones play this
## fanfare (queued until any running conversation ends, so "after the mayor
## finishes talking" just works, and several in a row play one after another).
## Future callers (a secret chest, a quest reward) only call
##   ItemGet.give(&"item_id")            # or give(id, count)
## and mark the ItemData `important` in ItemLibrary.
##
## One instance lives under UiRoot (ItemGet.instance).

static var instance: ItemGet

const JINGLE_PATH := "res://sounds/Music/item_jingle.ogg"
const BOX_DELAY := 0.9            ## pose + jingle get this long to land before the text box opens
const PROP_HEIGHT := 0.55         ## metres tall the held item is drawn
const PROP_RAISE := 0.5           ## metres above the head it floats
const PROP_SPIN := 1.6            ## rad/s
const PROP_BOB := 0.04            ## metres of up-and-down float
const PROP_POP_TIME := 0.45
const GLOW_COLOR := Color(1.0, 0.92, 0.6)

var _queue: Array[Dictionary] = []   ## [{item: ItemData, count: int}], oldest first
var _busy := false
var _entry: Dictionary = {}
var _player: Player
var _prop: Node3D
var _age := 0.0

func _ready() -> void:
	instance = self
	set_process(false)

func _exit_tree() -> void:
	if instance == self:
		instance = null
	_restore()

## Gives the player `count` of `id`. Important items play the fanfare (see the
## class doc); everything else just goes in the bag.
static func give(id: StringName, count := 1) -> void:
	var item := ItemLibrary.by_id(id)
	if instance == null or item == null or not item.important \
			or not Game.inventory.can_fit(id, count):
		Game.inventory.add(id, count)
		return
	instance._queue.append({"item": item, "count": count})
	instance._pump()

# --- Queue -------------------------------------------------------------------

func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	var box := DialogueBox.instance
	if box != null and box.is_active():
		# Wait for the conversation that handed this over to finish.
		if not Events.dialogue_ended.is_connected(_pump):
			Events.dialogue_ended.connect(_pump, CONNECT_ONE_SHOT)
		return
	_entry = _queue.pop_front()
	_play(_entry["item"])

# --- The moment --------------------------------------------------------------

func _play(item: ItemData) -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null or DialogueBox.instance == null:
		_finish()   # nobody to show it to (menus, tests): just hand it over
		return
	_busy = true
	_player.enter_cinematic()
	_face_camera()
	_player.visual.play_hold(PlayerVisual.ANIM_GET_ITEM, 600.0, 1.0, true, 0.1)
	_player.visual.hold_expression(&"happy")
	_spawn_prop(item)
	_play_jingle()
	Music.duck = true
	_age = 0.0
	set_process(true)
	await get_tree().create_timer(BOX_DELAY).timeout
	if not _busy:
		return   # cancelled while waiting (the player died, the scene was left)
	var box := DialogueBox.instance
	if box == null or box.is_active():
		_finish()
		return
	Events.dialogue_ended.connect(_on_box_closed, CONNECT_ONE_SHOT)
	box.start(DialogueNode.say("", "You got the [color=#ffd966]%s[/color]!" % item.display_name))

func _on_box_closed() -> void:
	_finish()

## Hands the item over, tears the moment down and moves on to the next one.
func _finish() -> void:
	_restore()
	if not _entry.is_empty():
		Game.inventory.add(_entry["item"].id, _entry["count"])
		_entry = {}
	await get_tree().create_timer(0.35).timeout
	_pump()

func _restore() -> void:
	_busy = false
	set_process(false)
	Music.duck = false
	if is_instance_valid(_player):
		_player.visual.cancel_hold()
		_player.visual.release_expression()
	if is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null
	_player = null

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_age += delta
	_face_camera()   # straight at the camera, even if it is orbited meanwhile
	if is_instance_valid(_prop):
		_prop.rotation.y += PROP_SPIN * delta
		_prop.position.y = Player.STAND_HEIGHT + PROP_RAISE + sin(_age * 2.4) * PROP_BOB

func _face_camera() -> void:
	var rig := _player.camera_rig
	var cam := rig.get_camera() if rig != null else null
	if cam == null:
		return
	_player.face(cam.global_position - _player.global_position)
	_player.visual.set_lean(0.0, 0.0, 1.0, 1.0)

# --- Pieces ------------------------------------------------------------------

func _play_jingle() -> void:
	if not ResourceLoader.exists(JINGLE_PATH):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(JINGLE_PATH)
	p.bus = &"SFX"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## The treasure floating over the player's head: the item's model if it has
## one, else its icon as a billboard, else a glowing orb in its colour.
func _spawn_prop(item: ItemData) -> void:
	_prop = Node3D.new()
	_prop.position = Vector3(0.0, Player.STAND_HEIGHT + PROP_RAISE, 0.0)
	_player.add_child(_prop)
	var shape := _make_shape(item)
	_prop.add_child(shape)
	var light := OmniLight3D.new()
	light.light_color = GLOW_COLOR
	light.light_energy = 1.6
	light.omni_range = 5.0
	light.light_specular = 0.0
	_prop.add_child(light)
	_prop.scale = Vector3.ZERO
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(_prop, "scale", Vector3.ONE, PROP_POP_TIME)

func _make_shape(item: ItemData) -> Node3D:
	if item.model != null:
		var model := item.model.instantiate() as Node3D
		ModelUtil.fit_height(model, PROP_HEIGHT)
		return model
	if item.icon != null:
		var sprite := Sprite3D.new()
		sprite.texture = item.icon
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = PROP_HEIGHT / maxf(item.icon.get_height(), 1.0)
		sprite.shaded = false
		return sprite
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = PROP_HEIGHT * 0.4
	mesh.height = PROP_HEIGHT * 0.8
	orb.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.color
	mat.emission_enabled = true
	mat.emission = item.color
	mat.emission_energy_multiplier = 1.5
	orb.material_override = mat
	return orb
