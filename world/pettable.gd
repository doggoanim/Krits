@tool
class_name Pettable
extends Interactable
## A little animal you can pet: press interact next to it and it wiggles, a heart floats up and
## it makes a noise (and sometimes says something). Pick the animal with `species`
## (CritterVisuals); set `snap_to_ground` to drop it onto the floor below where you place it.

enum Species { CAT, HEN, BIRD, KOI }

const NAMES := [&"cat", &"hen", &"bird", &"koi"]
const WORDS := {
	&"cat": ["Mrrp!", "Purrrr...", "Mew!", "*headbutt*"],
	&"hen": ["Bok bok!", "Cluck!", "Buk-buk-BAAWK!"],
	&"bird": ["Tweet!", "Chirp chirp!", "Tweeet-tweet!"],
	&"koi": ["Blub.", "Blub blub!", "*happy bubbles*"],
}
const PITCH := {&"cat": Vector2(1.6, 2.0), &"hen": Vector2(0.9, 1.2), &"bird": Vector2(2.1, 2.6), &"koi": Vector2(0.5, 0.7)}
const SOUND_CHANCE := 0.6
const COOLDOWN := 1.3
const HEART_COLOR := Color(1.0, 0.45, 0.6)

@export var species := Species.CAT:
	set(v):
		species = v
		_rebuild()
@export var snap_to_ground := true

var _critter: Node3D
var _t := randf() * 10.0
var _excite := 0.0
var _cool := 0.0

func _init() -> void:
	collision_layer = 0
	collision_mask = 0
	interact_radius = 1.6
	prompt_height = 0.9
	prompt_text = "Press E to pet"

func _ready() -> void:
	if species == Species.KOI:
		interact_radius = 2.2   # you pet it from the bank
	super()
	_rebuild()
	if snap_to_ground and not Engine.is_editor_hint():
		_snap()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _critter != null:
		_critter.queue_free()
	_critter = CritterVisuals.build(NAMES[species])
	_critter.name = "Critter"
	add_child(_critter)

func _snap() -> void:
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 3.0, global_position + Vector3.DOWN * 8.0, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and species != Species.KOI:   # a koi sits on the water, wherever you put it
		global_position.y = (hit["position"] as Vector3).y

func _can_interact() -> bool:
	return (player != null and not player.dead and not Game.in_combat and _cool <= 0.0
		and player.machine.current_name == &"Ground"
		and MenuBase.open_menu == null)

func _process(delta: float) -> void:
	super(delta)
	if _critter == null:
		return
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	_excite = maxf(_excite - delta * 0.8, 0.0)
	CritterVisuals.animate(_critter, NAMES[species], _t, minf(_excite, 1.0))

func _interact() -> void:
	_cool = COOLDOWN
	_excite = 1.0
	var key: StringName = NAMES[species]
	player.face(global_position - player.global_position)
	player.visual.squash_stretch(0.9, 1.08)
	_float_text("<3", HEART_COLOR, 0.0)
	if randf() < SOUND_CHANCE:
		var words: Array = WORDS[key]
		_float_text(words[randi() % words.size()], Color(1, 0.97, 0.88), 0.35)
		var pitch: Vector2 = PITCH[key]
		if species == Species.HEN:
			PropSfx.play_at(self, PropSfx.CLUCK, global_position, Vector2(1.0, 1.15), -6.0)
		else:
			PropSfx.play_at(self, PropSfx.SQUEAK, global_position, pitch, -2.0)

## A short word or heart that floats up above the animal and fades.
func _float_text(text: String, color: Color, delay: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0.1, 0.06, 0.05, 0.9)
	label.outline_size = 10
	label.font_size = 40
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.top_level = true
	add_child(label)
	label.global_position = global_position + Vector3.UP * 0.7 + Vector3(randf_range(-0.1, 0.1), 0, 0)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 0.8, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)
