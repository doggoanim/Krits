@tool
class_name BreakableBlock
extends StaticBody3D
## A block that only gives way to one specific move, performed with the right
## weapon:
##   * GROUND_POUND — slam down onto its top (a floor to break through), or
##   * AIR_DIVE     — dive, long-jump or roll into its side (a wall to break through).
## The player must be holding a weapon of `required_weapon`'s class whose
## power (WeaponData.damage_bonus) is at least `min_power`. Any other attempt
## with the right move just tells the player what's missing; any other move
## does nothing at all (it's a plain solid block).
##
## Example: the tutorial's wall in front of the water spirits — a SWORD with
## min_power 0.5, so the player must first find the wooden sword, then dive
## into it. Raise `min_power` above the wooden sword (0.5) to demand better.
##
## Placing one: drop this script on a StaticBody3D. With no CollisionShape3D
## child it builds its own box (`size`, `material`); or add your own mesh +
## collision as children. Give it a unique `block_id` and it stays broken for
## good (story flag "broken_<block_id>"); leave it empty to respawn each visit.
##
## How it's hit: PoundState / DiveState / LongJumpState call Player.impact_breakables(), which
## offers each surface the player just collided with to on_player_impact().
## Anything with that method can react to the player's moves the same way.

enum Method { GROUND_POUND, AIR_DIVE }

@export var block_id: StringName = &""
@export var break_with := Method.GROUND_POUND
@export var required_weapon := WeaponData.Kind.SWORD
## The equipped weapon's damage_bonus must be at least this (wooden sword 0.5,
## steel sword 1.0).
@export var min_power := 0.0
@export var size := Vector3(2.0, 2.0, 2.0):          ## only used when it builds its own box
	set(v):
		size = v
		_rebuild_body()
@export var material: Material:                      ## only used when it builds its own box
	set(v):
		material = v
		_rebuild_body()
@export var rubble_color := Color(0.66, 0.52, 0.36):
	set(v):
		rubble_color = v
		_rebuild_body()
@export var break_sound: AudioStream

const HINT_COOLDOWN_MSEC := 2500
static var _last_hint_msec := -100000

var _auto_nodes: Array[Node] = []   ## the box mesh/collision this script built itself

func _ready() -> void:
	# @tool: the box is built in the editor too, so the block is visible there.
	if not Engine.is_editor_hint() and block_id != &"" and Game.flag(_flag()):
		queue_free()
		return
	_rebuild_body()

func _flag() -> StringName:
	return StringName("broken_" + String(block_id))

## Called by Player.impact_breakables() for every surface a move just hit.
## Returns true if this block broke.
func on_player_impact(kind: StringName, p: Player, normal: Vector3, speed: float) -> bool:
	if not _is_my_move(kind, p, normal, speed):
		return false
	var weapon := Game.stats.equipped_weapon
	if weapon == null or weapon.kind != required_weapon:
		_hint("You need a %s to break this." % _weapon_class_name())
		return false
	if weapon.damage_bonus < min_power:
		_hint("The %s isn't strong enough to break this." % weapon.display_name)
		return false
	_break(p)
	return true

func _is_my_move(kind: StringName, p: Player, normal: Vector3, speed: float) -> bool:
	match break_with:
		Method.GROUND_POUND:
			return kind == &"pound" and normal.y > 0.5
		Method.AIR_DIVE:
			return (kind == &"dive" or kind == &"long_jump" or kind == &"roll") and absf(normal.y) < 0.5 and speed >= p.config.wall_min_speed
	return false

func _break(p: Player) -> void:
	if block_id != &"":
		Game.set_flag(_flag())
	var center := _center()
	var parent := get_parent() as Node3D
	if parent != null:
		VFX.shatter(parent, center, rubble_color, 1.6)
		VFX.shatter(parent, center + Vector3.UP * 0.4, rubble_color.lightened(0.15), 1.2)
		VFX.smoke_puff(parent, center, 1.4)
	if p.camera_rig:
		p.camera_rig.shake(0.4)
	if break_sound != null and parent != null:
		var sfx := AudioStreamPlayer3D.new()
		sfx.stream = break_sound
		sfx.bus = &"SFX"
		parent.add_child(sfx)
		sfx.global_position = center
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
	queue_free()

func _hint(text: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hint_msec < HINT_COOLDOWN_MSEC:
		return
	_last_hint_msec = now
	Events.notice.emit(text)

func _weapon_class_name() -> String:
	return String(WeaponData.Kind.keys()[required_weapon]).capitalize()

## Middle of the visible block (the first mesh found), else its origin.
func _center() -> Vector3:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			return mi.global_transform * mi.get_aabb().get_center()
	return global_position

## (Re)builds the plain box (mesh + collision) unless the scene supplies its own
## collision shape. Not saved into the scene file (the nodes have no owner).
func _rebuild_body() -> void:
	if not is_inside_tree():
		return
	var has_own_shape := false
	for child in get_children():
		if child is CollisionShape3D and child not in _auto_nodes:
			has_own_shape = true
	for node in _auto_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_auto_nodes.clear()
	if has_own_shape:
		return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	_auto_nodes.append(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material if material != null else _default_material()
	add_child(mi)
	_auto_nodes.append(mi)

func _default_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = rubble_color
	return m
