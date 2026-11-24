@tool
class_name TownBell
extends Interactable
## The bell on its frame in the square: press interact and you ring it. The sound goes through
## BellCall (so it's muffled indoors like the story bell), a shockwave ripples out from the bell,
## and folk nearby jump. It swings for a moment first. Doesn't touch the story bell's flags.

const RING_COOLDOWN := 3.0
const SWING := 0.5             ## radians at the top of the swing
const SWING_TIME := 2.2
const REACT_RADIUS := 22.0
const SHOCKWAVE := preload("res://world/bell_shockwave.gd")

var _pivot: Node3D
var _cool := 0.0
var _swing := 0.0
var _t := 0.0

func _init() -> void:
	prompt_text = "Press E to ring"
	prompt_height = 2.4
	interact_radius = 2.2

func _ready() -> void:
	super()
	var post := PlayProps.bell_post()
	add_child(post)
	_pivot = post.get_node("Bell") as Node3D
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 2.6, 0.3)
	shape.shape = box
	shape.position.y = 1.3
	add_child(shape)

func _process(delta: float) -> void:
	super(delta)
	_cool = maxf(_cool - delta, 0.0)
	_t += delta
	_swing = maxf(_swing - delta / SWING_TIME, 0.0)
	if _pivot != null:
		_pivot.rotation.x = sin(_t * 7.0) * SWING * _swing * _swing + sin(_t * 0.9) * 0.015   # always a faint sway

func _can_interact() -> bool:
	return (_cool <= 0.0 and player != null and not player.dead and not Game.in_combat
		and player.machine.current_name == &"Ground" and MenuBase.open_menu == null)

func _interact() -> void:
	_cool = RING_COOLDOWN
	_swing = 1.0
	player.face(global_position - player.global_position)
	player.visual.squash_stretch(1.08, 0.94)
	var calls := get_tree().get_nodes_in_group(BellCall.GROUP)
	if not calls.is_empty():
		(calls[0] as BellCall).ring(global_position + Vector3.UP * 2.0)
	else:   # no story bell in this scene: still ring, just not muffled
		PropSfx.play_at(self, BellCall.BELL_SFX, global_position + Vector3.UP * 2.0, Vector2(1, 1))
		_wave(global_position + Vector3.UP * 2.0)
	_startle_neighbours()

func _wave(at: Vector3) -> void:
	var wave: Node3D = SHOCKWAVE.new()
	get_tree().current_scene.add_child(wave)
	wave.global_position = at

## Characters in earshot give a little start.
func _startle_neighbours() -> void:
	for node in get_tree().get_nodes_in_group(&"npc"):
		if node is NPC and (node as NPC).global_position.distance_to(global_position) < REACT_RADIUS:
			(node as NPC).talk_pop()
