@tool
class_name Seat
extends Interactable
## A bench or log you can sit on. Press interact to sit (the player settles in facing the way
## the seat faces), time speeds up and your health slowly comes back; press interact again, or
## get hurt, and you stand. `requires_fire` (a log by a campfire) only lets you sit while the
## fire next to it is lit.
##
## Look: BENCH or LOG from PlayProps, which face local +Z (you face the way +Z points).

enum Kind { BENCH, LOG }

@export var kind := Kind.BENCH:
	set(v):
		kind = v
		_rebuild()
@export var sit_height := 0.32                ## how high above the seat's origin you sit
@export var rest_time_scale := 12.0           ## WorldClock.rest_scale while seated
@export var heal_per_second := 0.04           ## fraction of max HP regained per real second
@export var requires_fire := false
@export_node_path("Campfire") var fire_path: NodePath

var _visual: Node3D
var _sitting := false
var _sitter: Player   ## who is seated (kept apart from `player`, which clears when the area is left)
var _fire: Campfire

func _init() -> void:
	prompt_text = "Press E to sit"
	prompt_height = 1.2
	interact_radius = 1.6

func _ready() -> void:
	super()
	_rebuild()
	if not Engine.is_editor_hint() and not fire_path.is_empty():
		_fire = get_node_or_null(fire_path) as Campfire

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = PlayProps.bench() if kind == Kind.BENCH else PlayProps.log_seat()
	add_child(_visual)

func _exit_tree() -> void:
	if _sitting:
		_stand(false)
	super()

func _can_interact() -> bool:
	if player == null or player.dead or Game.in_combat or MenuBase.open_menu != null:
		return false
	if _sitting:
		return true
	if requires_fire and not _fire_lit():
		return false
	return player.machine.current_name == &"Ground"

func _fire_lit() -> bool:
	return _fire != null and is_instance_valid(_fire) and _fire.is_lit()

func _interact() -> void:
	if _sitting:
		_stand(true)
	else:
		_sit()

func _sit() -> void:
	_sitting = true
	_sitter = player
	_verb = "Stand up"
	player.enter_cinematic()
	player.global_position = global_position + global_basis.y * sit_height
	player.face(global_basis.z)
	player.velocity = Vector3.ZERO
	player.visual.play(PlayerVisual.ANIM_CROUCH_IDLE)
	WorldClock.rest_scale = rest_time_scale
	Events.player_hurt.connect(_on_hurt)
	Events.notice.emit("Resting...")

func _stand(announce: bool) -> void:
	_sitting = false
	_verb = _verb_from("Press E to sit")
	WorldClock.rest_scale = 1.0
	if Events.player_hurt.is_connected(_on_hurt):
		Events.player_hurt.disconnect(_on_hurt)
	if is_instance_valid(_sitter):
		_sitter.visual.cancel_hold()
		if _sitter.machine.current_name == &"Frozen":
			_sitter.machine.transition_to(&"Ground")
		if announce:
			_sitter.visual.squash_stretch(1.1, 0.92)
	_sitter = null

func _process(delta: float) -> void:
	super(delta)
	if not _sitting or Engine.is_editor_hint():
		return
	if requires_fire and not _fire_lit():
		_stand(true)   # the fire died down
		return
	if not is_instance_valid(_sitter) or _sitter.dead:
		_stand(false)
		return
	Game.stats.heal(Game.stats.max_hp() * heal_per_second * delta)

func _on_hurt(_amount: Variant = null) -> void:
	_stand(false)
