class_name NpcStomp
extends Area3D
## Lets the player bounce off a character's head. Attached automatically by NPC and
## ShopKeeper (see NpcStomp.attach), so every character is stompable without scene edits.
##
## A thin zone sits over the top of the parent's collision shape. When the player is falling
## into it: they pop back up, a squeak plays, the character squashes (talk_pop) and says a
## random line over their head (barks.cfg key `stomp`, with the [Stomp] section as the
## fallback for characters who have none of their own).

const SQUEAK := preload("res://sounds/SFX/toy_squeak.wav")
const SECTION_FALLBACK := "Stomp"
const KEY := "stomp"
const SFX_BUS := &"SFX"

@export var min_fall_speed := 1.5          ## the player must be falling at least this fast
@export var bounce_lift := 0.85            ## fraction of the orb bounce height
@export var pitch_range := Vector2(0.85, 1.25)
@export var cooldown := 0.4
@export var zone_depth := Vector2(0.3, 0.4)   ## how far the zone reaches below / above the head

var _parent: Node3D
var _prev_vy := 0.0
var _cool := 0.0

## Adds a stomp zone to `target` (once). Does nothing in the editor.
static func attach(target: Node3D) -> NpcStomp:
	if Engine.is_editor_hint() or target.get_node_or_null("Stomp") != null:
		return null
	var stomp := NpcStomp.new()
	stomp.name = "Stomp"
	target.add_child(stomp)
	return stomp

func _ready() -> void:
	_parent = get_parent() as Node3D
	collision_layer = 0
	collision_mask = 1 << 1   # player
	var box := _head_box()
	if box.size == Vector3.ZERO or _parent == null:
		set_physics_process(false)
		return
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(box.size.x, zone_depth.x + zone_depth.y, box.size.z)
	shape.shape = b
	shape.position = Vector3(box.get_center().x, box.end.y + (zone_depth.y - zone_depth.x) * 0.5, box.get_center().z)
	add_child(shape)
	_ensure_barks(box.end.y)

## Bounds of the parent's first collision shape, in the parent's local space.
func _head_box() -> AABB:
	for child in _parent.get_children():
		if child is CollisionShape3D and child.shape != null:
			var cs := child as CollisionShape3D
			var aabb := cs.shape.get_debug_mesh().get_aabb()
			return cs.transform * aabb
	return AABB()

## Characters without a Barks child get a silent one (chance 0) just for stomp lines.
func _ensure_barks(top: float) -> void:
	if _barks() != null:
		return
	var barks := NpcBarks.new()
	barks.name = "Barks"
	barks.chance = 0.0
	barks.height = top + 0.6
	_parent.add_child(barks)

func _barks() -> NpcBarks:
	for child in _parent.get_children():
		if child is NpcBarks:
			return child
	return null

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
	_stomp(player)

func _stomp(player: Player) -> void:
	player.bounce_off_head(bounce_lift)
	_play_squeak()
	if _parent is NPC:
		(_parent as NPC).talk_pop()
	var barks := _barks()
	if barks != null:
		var line := NpcBarks.pick_stomp_line(String(_parent.name))
		if not line.is_empty():
			barks.say(line)

func _play_squeak() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = SQUEAK
	sfx.bus = SFX_BUS
	sfx.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
