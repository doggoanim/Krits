class_name SquashModifier
extends SkeletonModifier3D
## Bends the character's proportions on top of whatever animation is playing,
## so a jump can stretch the UPPER body first and let the legs follow, instead
## of scaling the whole model from the feet (which reads as stretching up from
## the head). Child of the Skeleton3D; runs after the animation each frame.
##
## It reads two numbers from the PlayerVisual and applies them:
##   spine_stretch  fraction of body height the upper body (chest, head, arms)
##                  is lifted away from the hips (negative = pressed down)
##   leg_stretch    fraction the legs lengthen (negative = shorten)

const UPPER_BONE := &"UpperTorso"
const HEAD_BONE := &"Head"
const LEG_BONES: Array[StringName] = [&"UpperLeg.L", &"UpperLeg.R"]

var visual: Node   ## the PlayerVisual (untyped so the two scripts never depend on each other at parse time)

var _upper := -1
var _legs: Array[int] = []
var _height := 0.0   ## body height in the skeleton's own units
var _resolved := false
var _announced := false   ## prints once the first time it has something to apply (to confirm it runs at all)

func _resolve(skeleton: Skeleton3D) -> void:
	_resolved = true
	_upper = skeleton.find_bone(UPPER_BONE)
	_legs.clear()
	for bone_name in LEG_BONES:
		var i := skeleton.find_bone(bone_name)
		if i >= 0:
			_legs.append(i)
	var head := skeleton.find_bone(HEAD_BONE)
	_height = skeleton.get_bone_global_rest(head).origin.y if head >= 0 else 0.0

## Which of these two the engine calls depends on its version (newer ones call
## the with-delta one, and only fall back to the plain one for old scripts), so
## both exist and do the same thing.
func _process_modification_with_delta(_delta: float) -> void:
	_apply()

func _process_modification() -> void:
	_apply()

func _apply() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or visual == null:
		return
	if not _resolved:
		_resolve(skeleton)
	if not _announced and (absf(visual.spine_stretch) > 0.0001 or absf(visual.leg_stretch) > 0.0001):
		_announced = true
		print("SquashModifier: running (upper bone %d, %d leg bones, body height %.2f)" % [_upper, _legs.size(), _height])
	var spine: float = visual.spine_stretch
	if _upper >= 0 and _height > 0.0 and absf(spine) > 0.0001:
		skeleton.set_bone_pose_position(_upper,
				skeleton.get_bone_pose_position(_upper) + Vector3(0.0, spine * _height, 0.0))
	var legs: float = visual.leg_stretch
	if absf(legs) > 0.0001:
		for i in _legs:
			skeleton.set_bone_pose_scale(i, skeleton.get_bone_pose_scale(i) * Vector3(1.0, 1.0 + legs, 1.0))
