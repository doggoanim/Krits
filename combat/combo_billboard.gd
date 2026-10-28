class_name ComboBillboard
extends Node3D
## The sword's combo counter: a hand-drawn plate that floats over the player,
## always facing the camera. Each orb hit pops it ("x3"); when the player
## lands it slams to the total damage dealt and shrinks away.
## Layout/art lives in combat/combo_billboard.tscn; tune the look with the
## exports here.

@export var plates: Array[Texture2D] = []                 ## a random one per pop
@export var tier_colors: Array[Color] = [
	Color(1, 1, 1), Color(1, 0.93, 0.5), Color(1, 0.72, 0.4), Color(1, 0.5, 0.45), Color(1, 0.55, 0.85)]
@export var combo_per_tier := 3        ## combo steps before the plate heats up a tier
@export var bob_height := 0.06
@export var bob_speed := 5.0

@onready var _pivot: Node3D = %Pivot
@onready var _plate: Sprite3D = %Plate
@onready var _count: Label3D = %Count

var _tween: Tween
var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
	_base_y = _pivot.position.y
	_pivot.scale = Vector3.ZERO

func _process(delta: float) -> void:
	_t += delta
	_pivot.position.y = _base_y + sin(_t * bob_speed) * bob_height

## An orb was hit: show/pop the running combo.
func set_combo(count: int) -> void:
	_count.text = "x%d" % count
	_restyle(count)
	_restart_tween()
	_pivot.scale = Vector3.ONE * 1.7
	_tween.tween_property(_pivot, "scale", Vector3.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## The player landed: slam to the damage total, hold a beat, shrink away.
func slam(total_damage: float) -> void:
	var whole := is_equal_approx(total_damage, roundf(total_damage))
	_count.text = ("%d" if whole else "%.1f") % total_damage
	_plate.modulate = Color.WHITE
	_restart_tween()
	_pivot.scale = Vector3.ONE * 0.6
	_tween.tween_property(_pivot, "scale", Vector3.ONE * 2.1, 0.07) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_pivot, "scale", Vector3.ONE * 1.6, 0.12)
	_tween.tween_interval(0.35)
	_tween.tween_property(_pivot, "scale", Vector3.ZERO, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

## Hide with no ceremony (fight over, or a landing with nothing banked).
func dismiss() -> void:
	_restart_tween()
	_tween.tween_property(_pivot, "scale", Vector3.ZERO, 0.15)

func _restyle(count: int) -> void:
	if not plates.is_empty():
		_plate.texture = plates.pick_random()
	var tier := mini((count - 1) / maxi(combo_per_tier, 1), tier_colors.size() - 1)
	_plate.modulate = tier_colors[tier]

func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
