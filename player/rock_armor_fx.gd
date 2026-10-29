class_name RockArmorFx
extends Node3D
## The Earth spell's armor, drawn on the player: a crust of randomly sized,
## randomly turned rocks (cubes in the earth element's color) stacked all over
## the body. Each rock is attached to one of the character's skeleton bones
## (BoneAttachment3D), so the armor follows the animation — arms swing, legs
## step, the torso leans — instead of floating around the collision capsule.
## Child of the player's visual. Driven by Events.rock_armor_changed: as the
## armor's shield drains, rocks drop off in proportion; it shatters on
## Events.rock_armor_broken.

const ROCK_COUNT := 48

## Per bone of Krits.glb: spawn weight, the rocks' size range and how far (m)
## they spread sideways of the bone — torso bones are wide, limbs slim.
const BONES := {
	&"LowerTorso": {"weight": 6.0, "size": Vector2(0.22, 0.36), "spread": Vector2(0.22, 0.17)},
	&"UpperTorso": {"weight": 9.0, "size": Vector2(0.22, 0.36), "spread": Vector2(0.24, 0.18)},
	&"Head": {"weight": 3.0, "size": Vector2(0.16, 0.26), "spread": Vector2(0.15, 0.15)},
	&"UpperArm.L": {"weight": 3.0, "size": Vector2(0.15, 0.24), "spread": Vector2(0.09, 0.09)},
	&"UpperArm.R": {"weight": 3.0, "size": Vector2(0.15, 0.24), "spread": Vector2(0.09, 0.09)},
	&"LowerArm.L": {"weight": 2.0, "size": Vector2(0.13, 0.2), "spread": Vector2(0.08, 0.08)},
	&"LowerArm.R": {"weight": 2.0, "size": Vector2(0.13, 0.2), "spread": Vector2(0.08, 0.08)},
	&"UpperLeg.L": {"weight": 4.0, "size": Vector2(0.17, 0.27), "spread": Vector2(0.1, 0.1)},
	&"UpperLeg.R": {"weight": 4.0, "size": Vector2(0.17, 0.27), "spread": Vector2(0.1, 0.1)},
	&"LowerLeg.L": {"weight": 3.0, "size": Vector2(0.14, 0.22), "spread": Vector2(0.09, 0.09)},
	&"LowerLeg.R": {"weight": 3.0, "size": Vector2(0.14, 0.22), "spread": Vector2(0.09, 0.09)},
	&"Foot.L": {"weight": 1.0, "size": Vector2(0.12, 0.18), "spread": Vector2(0.07, 0.07)},
	&"Foot.R": {"weight": 1.0, "size": Vector2(0.12, 0.18), "spread": Vector2(0.07, 0.07)},
}

var _rocks: Array[MeshInstance3D] = []
var _outlines: Array[MeshInstance3D] = []   ## CelOutline adds each outline as a sibling mesh, so they're tracked beside the rocks

func _ready() -> void:
	var visual := get_parent() as PlayerVisual
	var skeleton: Skeleton3D = null
	if visual and visual.get_model():
		skeleton = visual.get_model().find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_warning("RockArmorFx: no Skeleton3D found on the player model — no armor will be shown")
		return
	_build(skeleton)
	Events.rock_armor_changed.connect(_on_changed)
	Events.rock_armor_broken.connect(_on_broken)
	_on_changed(Game.stats.rock_shield, Game.stats.rock_shield_max)

func _build(skeleton: Skeleton3D) -> void:
	# Bone-local units are the model's own, scaled by whatever the character
	# is scaled to (ModelUtil.fit_height) — convert metres to bone units.
	var unit := maxf(skeleton.global_basis.get_scale().x, 0.0001)
	var color: Color = Orb.KIND_COLORS[Orb.Kind.EARTH][0]
	var attachments := {}
	var names: Array = []
	var weights: Array = []
	for bone_name: StringName in BONES:
		if skeleton.find_bone(bone_name) >= 0:
			names.append(bone_name)
			weights.append(BONES[bone_name]["weight"])
	for i in ROCK_COUNT:
		var bone_name: StringName = names[_pick_weighted(weights)]
		var info: Dictionary = BONES[bone_name]
		var bone_idx := skeleton.find_bone(bone_name)
		if not attachments.has(bone_name):
			var att := BoneAttachment3D.new()
			att.bone_name = bone_name
			skeleton.add_child(att)
			attachments[bone_name] = att
		var att: BoneAttachment3D = attachments[bone_name]

		var rock := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size_range: Vector2 = info["size"]
		var s := randf_range(size_range.x, size_range.y) / unit
		box.size = Vector3(s, s * randf_range(0.7, 1.2), s * randf_range(0.8, 1.3))
		rock.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.lerp(Color.BLACK, randf_range(0.0, 0.25)).lerp(Color.WHITE, randf_range(0.0, 0.12))
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		rock.material_override = mat
		# Somewhere along the bone (toward its first child) and out to the side.
		var along := _bone_length(skeleton, bone_idx) * randf_range(0.0, 1.0)
		var spread: Vector2 = info["spread"]
		var ang := randf() * TAU
		rock.position = Vector3(cos(ang) * spread.x, along * unit, sin(ang) * spread.y) / unit
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		rock.visible = false
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(rock)
		_outlines.append(CelOutline.apply(rock, 0.025 / unit))
		_rocks.append(rock)

## Length of `bone`'s first child bone offset, in bone units (0 for a leaf).
func _bone_length(skeleton: Skeleton3D, bone: int) -> float:
	var children := skeleton.get_bone_children(bone)
	if children.is_empty():
		return 0.0
	return skeleton.get_bone_rest(children[0]).origin.length()

func _pick_weighted(weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := randf() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return i
	return weights.size() - 1

func _on_changed(shield: float, max_shield: float) -> void:
	var frac := clampf(shield / max_shield, 0.0, 1.0) if max_shield > 0.0 else 0.0
	var want := ceili(frac * _rocks.size()) if shield > 0.0 else 0
	for i in _rocks.size():
		var rock := _rocks[i]
		var on := i < want
		if on and not rock.visible:
			_pop_in(rock, i)
		rock.visible = on
		_sync_outline(i)

## Rocks thump onto the body one after another.
func _pop_in(rock: MeshInstance3D, index: int) -> void:
	rock.scale = Vector3.ZERO
	create_tween().tween_property(rock, "scale", Vector3.ONE, 0.25) \
		.set_delay(0.015 * index).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Keeps rock i's outline mesh matching it (visibility, scale while it pops in).
func _sync_outline(i: int) -> void:
	var outline := _outlines[i]
	var rock := _rocks[i]
	outline.visible = rock.visible
	outline.scale = rock.scale
	outline.position = rock.position
	outline.rotation = rock.rotation

func _process(_delta: float) -> void:
	for i in _rocks.size():
		if _rocks[i].visible:
			_sync_outline(i)

func _on_broken() -> void:
	var color: Color = Orb.KIND_COLORS[Orb.Kind.EARTH][0]
	VFX.shatter(self, global_position + Vector3.UP * 0.9, color, 1.5)
	VFX.shatter(self, global_position + Vector3.UP * 1.4, color.lightened(0.2), 1.1)
