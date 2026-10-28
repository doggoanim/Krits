class_name GearDisplay
extends Node3D
## Shows what the player has equipped as a floating rig behind them:
##
##   Player ──(lagged follow)──> shield anchor (FloatingAnchor)
##                                  ├─ shield model
##                                  └─ weapon pivot (the shield's top edge) ── weapon model (swings)
##
## The shield floats at the player's back; the weapon hangs off the back of
## the shield, so it inherits the shield's lag and adds its own pendulum
## swing. Models, scale, offset and tilt come from EquipmentData
## (model / model_scale / model_offset / model_rotation_deg) — add a .glb to
## an item in EquipmentLibrary and it appears here. Armor is not handled yet.
##
## Rebuilds itself whenever the equipped shield/weapon changes
## (Events.stats_changed). Created by Player (add it after `visual`).

@export var shield_rest := Vector3(0.0, 1.15, 0.55)   ## relative to the player's facing; +Z is behind
@export var shield_default_top := 0.25   ## height of the shield's top edge when there is no shield model
@export var weapon_hang_back := 0.05     ## how far behind the shield face the weapon hangs
@export var swing_strength := 0.06     ## radians of weapon swing per m/s of anchor speed
@export var swing_max := 0.7           ## radians
@export var swing_follow := 12.0       ## spring stiffness (higher = snappier)
@export var swing_spring := 4.0        ## damping (higher = settles faster, less wobble)

var _player: Player
var _anchor: FloatingAnchor
var _weapon_pivot: Node3D
var _shield_model: Node3D
var _weapon_model: Node3D
var _shield_id: StringName = &"?"
var _weapon_id: StringName = &"?"
var _swing := Vector2.ZERO        ## (pitch, roll) offset of the weapon
var _swing_vel := Vector2.ZERO

func _ready() -> void:
	_player = get_parent() as Player   # created by Player, which must already have its visual
	_anchor = FloatingAnchor.new()
	_anchor.name = "ShieldAnchor"
	add_child(_anchor)
	_weapon_pivot = Node3D.new()
	_weapon_pivot.name = "WeaponPivot"
	_anchor.add_child(_weapon_pivot)
	Events.stats_changed.connect(_refresh)
	_place_weapon_pivot()
	_refresh()
	_anchor.snap_to(_target_position(), _target_yaw())

func _physics_process(delta: float) -> void:
	if _player == null or _player.visual == null:
		return
	var vel := _anchor.follow(_target_position(), _target_yaw(), delta)
	_update_swing(vel, delta)

# ---------------------------------------------------------------- follow

func _target_yaw() -> float:
	return _player.visual.global_rotation.y

func _target_position() -> Vector3:
	var facing_basis := Basis(Vector3.UP, _target_yaw())
	return _player.visual.global_position + facing_basis * shield_rest   # the model, not the collision body

## The weapon is a damped spring: anchor motion (in the anchor's own frame)
## pulls it off-centre, so it trails when you run, kicks when you stop, and
## settles back.
func _update_swing(world_vel: Vector3, delta: float) -> void:
	var local := _anchor.global_basis.inverse() * world_vel
	# forward/back speed pitches the weapon, sideways speed rolls it
	var target := Vector2(
		clampf(local.z * swing_strength, -swing_max, swing_max),
		clampf(-local.x * swing_strength, -swing_max, swing_max))
	var accel := (target - _swing) * swing_follow * swing_follow - _swing_vel * 2.0 * swing_spring
	_swing_vel += accel * delta
	_swing += _swing_vel * delta
	_weapon_pivot.rotation = Vector3(_swing.x, 0.0, _swing.y)

# ---------------------------------------------------------------- equipment

func _refresh() -> void:
	var stats := Game.stats
	var shield := stats.equipped_shield
	var weapon := stats.equipped_weapon
	var shield_id := shield.id if shield else &""
	var weapon_id := weapon.id if weapon else &""
	if shield_id != _shield_id:
		_shield_id = shield_id
		_shield_model = _swap(_shield_model, _anchor, shield)
		_place_weapon_pivot()
	if weapon_id != _weapon_id:
		_weapon_id = weapon_id
		_weapon_model = _swap(_weapon_model, _weapon_pivot, weapon)

## Frees `old`, instances `item`'s model under `parent` (if it has one) with
## the item's scale/offset/tilt applied, and returns it (or null).
func _swap(old: Node3D, parent: Node3D, item: EquipmentData) -> Node3D:
	if old and is_instance_valid(old):
		old.queue_free()
	if item == null or item.model == null:
		return null
	var node := item.model.instantiate() as Node3D
	if node == null:
		return null
	node.scale = Vector3.ONE * item.model_scale
	node.position = item.model_offset
	node.rotation_degrees = item.model_rotation_deg
	parent.add_child(node)
	return node

## The weapon hangs from the top edge of the shield, just behind its face.
func _place_weapon_pivot() -> void:
	var top := shield_default_top
	if _shield_model and is_instance_valid(_shield_model):
		top = _top_edge(_shield_model)
	_weapon_pivot.position = Vector3(0.0, top, -weapon_hang_back)

## Highest point of a model's meshes, in the anchor's space.
func _top_edge(model: Node3D) -> float:
	var top := -INF
	var to_anchor := _anchor.global_transform.affine_inverse()
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box := (to_anchor * mi.global_transform) * mi.get_aabb()
		top = maxf(top, box.end.y)
	return top if top > -INF else shield_default_top
