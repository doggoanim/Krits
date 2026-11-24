class_name StompZone
extends Area3D
## Makes the top of anything bouncy: land on it while falling and you hop back up, with a
## squeak and a squash. Add as a CHILD of a node that has a CollisionShape3D (the zone sits
## over that shape's top). NpcStomp extends this for characters; BouncyProp uses it as is.
##
## Override _react() to change what the thing does when stomped; connect `stomped` to hook in.

signal stomped(player: Player)

const SQUEAK := preload("res://sounds/SFX/toy_squeak.wav")
const SFX_BUS := &"SFX"
const PLAYER_LAYER := 1 << 1

@export var min_fall_speed := 1.5              ## the player must be falling at least this fast
@export var bounce_lift := 0.85                ## fraction of the orb bounce height
@export var pitch_range := Vector2(0.85, 1.25)
@export var cooldown := 0.4
@export var zone_depth := Vector2(0.3, 0.4)    ## how far the zone reaches below / above the top
@export var squash_target: Node3D              ## squashed on a stomp (default: the parent)
@export var squash := Vector2(1.18, 0.7)       ## (x/z, y) scale at the bottom of the squash

var _parent: Node3D
var _top := 0.0
var _prev_vy := 0.0
var _cool := 0.0
var _squash_tween: Tween

func _ready() -> void:
	_parent = get_parent() as Node3D
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	var box := _head_box()
	if box.size == Vector3.ZERO or _parent == null:
		set_physics_process(false)
		return
	_top = box.end.y
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(box.size.x, zone_depth.x + zone_depth.y, box.size.z)
	shape.shape = b
	shape.position = Vector3(box.get_center().x, _top + (zone_depth.y - zone_depth.x) * 0.5, box.get_center().z)
	add_child(shape)
	if squash_target == null:
		squash_target = _parent
	_setup(box)

## Bounds of the parent's first collision shape, in the parent's local space.
func _head_box() -> AABB:
	for child in _parent.get_children():
		if child is CollisionShape3D and child.shape != null:
			var cs := child as CollisionShape3D
			return cs.transform * cs.shape.get_debug_mesh().get_aabb()
	return AABB()

## Subclass hook, called once the zone exists; `box` is the parent's collision bounds.
func _setup(_box: AABB) -> void:
	pass

func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	var vy := minf(player.velocity.y, _prev_vy)   # a landing frame has already zeroed velocity.y
	_prev_vy = player.velocity.y
	if _cool > 0.0 or vy > -min_fall_speed or not overlaps_body(player):
		return
	_cool = cooldown
	player.bounce_off_head(bounce_lift)
	play_squeak()
	_react(player)
	stomped.emit(player)

## What the stomped thing does. Default: a squash and rebound.
func _react(_player: Player) -> void:
	squash_pop(squash_target)

func play_squeak() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = SQUEAK
	sfx.bus = SFX_BUS
	sfx.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()

## Squashes `target` flat and springs it back (feet stay planted: scaling is about its origin).
func squash_pop(target: Node3D) -> void:
	if target == null:
		return
	var rest := Vector3.ONE
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
		rest = target.get_meta(&"stomp_rest_scale", Vector3.ONE)
	else:
		rest = target.scale
		target.set_meta(&"stomp_rest_scale", rest)
	var down := Vector3(squash.x, squash.y, squash.x)
	_squash_tween = create_tween()
	_squash_tween.tween_property(target, "scale", rest * down, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(target, "scale", rest * Vector3(1.0 / squash.x, 1.0 / squash.y * 0.9 + 0.1, 1.0 / squash.x), 0.12).set_trans(Tween.TRANS_SINE)
	_squash_tween.tween_property(target, "scale", rest, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
