class_name FishingRod
extends RefCounted
## The fishing rod in the player's hand for the length of a cast (the
## FishingSession creates it and releases it). The glb is parented to the right
## forearm's grip (HandGrips.make_grip, placement from player/hand_grips.tres:
## rod_offset / rod_rotation_deg / rod_scale), so the fishing animations carry it.
## tip_position() is where the line leaves the rod.

const MODEL: PackedScene = preload("res://assets/equipments/fishing_rod.glb")
const GRIPS: HandGrips = preload("res://player/hand_grips.tres")
const HAND_BONE := &"LowerArm.R"

var _grip: Node3D
var _model: Node3D
var _tip_local := Vector3.ZERO   ## the rod's far end, in the model's own space

## Puts a rod in `player`'s hand. Null if the character has no skeleton.
static func equip(player: Player) -> FishingRod:
	var model_root := player.visual.get_model() if player.visual else null
	var skeleton := model_root.find_child("Skeleton3D", true, false) as Skeleton3D if model_root else null
	if skeleton == null:
		return null
	var rod := FishingRod.new()
	rod._grip = HandGrips.make_grip(skeleton, HAND_BONE, GRIPS.rod_offset, GRIPS.rod_rotation_deg)
	if rod._grip == null:
		return null
	rod._model = MODEL.instantiate() as Node3D
	rod._model.scale = Vector3.ONE * GRIPS.rod_scale
	rod._grip.add_child(rod._model)
	ModelUtil.apply_cel_shading(rod._model, [], {}, Callable(OutlineSystem, &"mark"))
	rod._measure_tip()
	return rod

func _measure_tip() -> void:
	var to_model := _model.global_transform.affine_inverse()
	var top := -INF
	var centre := Vector3.ZERO
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box := (to_model * mi.global_transform) * mi.get_aabb()
		if box.end.y > top:
			top = box.end.y
			centre = box.get_center()
	_tip_local = Vector3(centre.x, top if top > -INF else 0.0, centre.z)

## World position of the rod's tip.
func tip_position() -> Vector3:
	return _model.global_transform * _tip_local if is_instance_valid(_model) else Vector3.ZERO

## Takes the rod out of the hand.
func release() -> void:
	if is_instance_valid(_grip):
		var attachment := _grip.get_parent().get_parent()   # grip -> end node -> BoneAttachment3D
		attachment.queue_free()
	_grip = null
	_model = null
