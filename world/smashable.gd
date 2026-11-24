@tool
class_name Smashable
extends StaticBody3D
## A solid thing that bursts when the player smashes into it: ground-pound onto it, or dive /
## long-jump / roll into it (a roll needs less speed than a dive). Bursts into pieces with a
## sound and drops what data/drops.cfg lists under `drop_section` (`gold` is a valid key).
##
## Two ways to get one:
##   * PlayProp extends this (pots, crates, barrels placed in a level);
##   * Smashable.make(body, ...) turns an existing StaticBody3D (the collision block of a crate
##     cluster, a shop's crate) into one. When it breaks, every mesh under the body's parent is
##     hidden and the collision switched off.
##
## The hit is found two ways: Player.impact_breakables() calls on_player_impact() for surfaces
## the move collided with, and a slightly oversized sensor catches a roll or dive that only
## brushed it.

const SENSOR_MARGIN := 0.3
const WOOD_RUBBLE := Color(0.72, 0.52, 0.32)

@export var drop_section: StringName = &"prop_crate"
@export var rubble := WOOD_RUBBLE
@export var wooden := true                           ## false = a clink instead of a crack
@export var break_pitch := Vector2(0.95, 1.15)
@export var min_dive_speed := 6.0                    ## dive / long jump
@export var min_roll_speed := 3.5

var _broken := false
var _sensor: Area3D

## Turns `body` (already holding its CollisionShape3D) into a Smashable.
static func make(body: StaticBody3D, section: StringName, color := WOOD_RUBBLE, wood := true) -> void:
	if Engine.is_editor_hint():
		return
	body.set_script(Smashable)
	body.set("drop_section", section)
	body.set("rubble", color)
	body.set("wooden", wood)

func _ready() -> void:
	if not Engine.is_editor_hint():
		_arm()

## (Re)builds the sensor around this body's first collision shape.
func _arm() -> void:
	if Engine.is_editor_hint():
		return
	if _sensor != null:
		_sensor.queue_free()
		_sensor = null
	var box := _bounds()
	if box.size == Vector3.ZERO:
		return
	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1 << 1
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = box.size + Vector3(SENSOR_MARGIN * 2.0, 0.0, SENSOR_MARGIN * 2.0)
	shape.shape = b
	shape.position = box.get_center()
	_sensor.add_child(shape)
	add_child(_sensor)

## Bounds of the first collision shape, in this body's local space.
func _bounds() -> AABB:
	for child in get_children():
		if child is CollisionShape3D and child.shape != null and child != _sensor:
			var cs := child as CollisionShape3D
			return cs.transform * cs.shape.get_debug_mesh().get_aabb()
	return AABB()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _broken or _sensor == null:
		return
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p == null or not _sensor.overlaps_body(p):
		return
	var speed := p.get_hvel().length()
	match p.machine.current_name:
		&"Roll":
			if speed >= min_roll_speed:
				_smash(p)
		&"Dive", &"LongJump":
			if speed >= min_dive_speed:
				_smash(p)

## Called by Player.impact_breakables() for every surface a move just hit.
func on_player_impact(move: StringName, p: Player, normal: Vector3, speed: float) -> bool:
	if _broken:
		return false
	var hit := false
	match move:
		&"pound": hit = normal.y > 0.5
		&"roll": hit = absf(normal.y) < 0.5 and speed >= min_roll_speed
		&"dive", &"long_jump": hit = absf(normal.y) < 0.5 and speed >= min_dive_speed
	if hit:
		_smash(p)
	return hit

func _smash(p: Player) -> void:
	if _broken:
		return
	_broken = true
	var box := _bounds()
	var center := global_transform * box.get_center()
	var parent := get_parent() as Node3D
	if parent != null:
		VFX.shatter(parent, center, rubble, 1.1)
		VFX.shatter(parent, center + Vector3.UP * 0.2, rubble.lightened(0.15), 0.8)
		VFX.smoke_puff(parent, center, 0.8)
	PropSfx.play_at(self, PropSfx.WOOD_CHOP if wooden else PropSfx.TINK, center, break_pitch if wooden else Vector2(1.5, 1.9))
	if p.camera_rig:
		p.camera_rig.shake(0.2)
	_give_drops()
	_remove()

## What happens to the thing itself. Default (a retrofitted block): hide the meshes around it
## and stop colliding. PlayProp overrides this to delete itself.
func _remove() -> void:
	var root := get_parent()
	if root != null:
		for node in root.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).visible = false
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).set_deferred(&"disabled", true)
	if _sensor != null:
		_sensor.queue_free()
		_sensor = null

## Rolls this thing's section of data/drops.cfg straight into the bag.
func _give_drops() -> void:
	var found: PackedStringArray = []
	for drop in Drops.for_enemy(drop_section):
		var n := drop.roll()
		if n <= 0:
			continue
		if drop.item_id == &"gold":
			Game.stats.add_gold(n)
			found.append("%d gold" % n)
			continue
		ItemGet.give(drop.item_id, n)
		var item := ItemLibrary.by_id(drop.item_id)
		found.append("%dx %s" % [n, item.display_name if item != null else String(drop.item_id)])
	if not found.is_empty():
		Events.notice.emit("Found " + ", ".join(found))
