class_name RockArmorFx
extends Node3D
## The Earth spell's armor, drawn on the player: a crust of randomly sized,
## randomly turned cubes in the earth element's color stacked all over the
## body. Child of the player's visual (so it follows the model, not the
## collision body). Driven by Events.rock_armor_changed: as the armor's
## shield drains, cubes drop off in proportion; it shatters on
## Events.rock_armor_broken.

const CUBE_COUNT := 20
const BODY_RADIUS := 0.42
const BODY_HEIGHT := 1.75

var _cubes: Array[MeshInstance3D] = []
var _outlines: Array[MeshInstance3D] = []   ## CelOutline adds each outline as a sibling mesh, so they're tracked beside the cubes
var _shown := 0

func _ready() -> void:
	var color: Color = Orb.KIND_COLORS[Orb.Kind.EARTH][0]
	for i in CUBE_COUNT:
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := randf_range(0.18, 0.34)
		box.size = Vector3(s, s * randf_range(0.7, 1.2), s * randf_range(0.8, 1.3))
		cube.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.lerp(Color.BLACK, randf_range(0.0, 0.25)).lerp(Color.WHITE, randf_range(0.0, 0.12))
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		cube.material_override = mat
		var ang := randf() * TAU
		var r := BODY_RADIUS + randf_range(-0.02, 0.1)
		cube.position = Vector3(cos(ang) * r, randf_range(0.12, BODY_HEIGHT), sin(ang) * r)
		cube.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		cube.visible = false
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cube)
		_outlines.append(CelOutline.apply(cube, 0.025))
		_cubes.append(cube)
	Events.rock_armor_changed.connect(_on_changed)
	Events.rock_armor_broken.connect(_on_broken)
	_on_changed(Game.stats.rock_shield, Game.stats.rock_shield_max)

func _on_changed(shield: float, max_shield: float) -> void:
	var frac := clampf(shield / max_shield, 0.0, 1.0) if max_shield > 0.0 else 0.0
	var want := ceili(frac * CUBE_COUNT) if shield > 0.0 else 0
	for i in CUBE_COUNT:
		var cube := _cubes[i]
		var on := i < want
		if on and not cube.visible:
			_pop_in(cube, i)
		cube.visible = on
		_sync_outline(i)
	_shown = want

## Cubes thump onto the body one after another.
func _pop_in(cube: MeshInstance3D, index: int) -> void:
	cube.scale = Vector3.ZERO
	create_tween().tween_property(cube, "scale", Vector3.ONE, 0.25) \
		.set_delay(0.02 * index).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Keeps cube i's outline mesh matching it (visibility, scale while it pops in).
func _sync_outline(i: int) -> void:
	var outline := _outlines[i]
	var cube := _cubes[i]
	outline.visible = cube.visible
	outline.scale = cube.scale
	outline.position = cube.position
	outline.rotation = cube.rotation

func _process(_delta: float) -> void:
	for i in CUBE_COUNT:
		if _cubes[i].visible:
			_sync_outline(i)

func _on_broken() -> void:
	var color: Color = Orb.KIND_COLORS[Orb.Kind.EARTH][0]
	VFX.shatter(self, global_position + Vector3.UP * 0.9, color, 1.5)
	VFX.shatter(self, global_position + Vector3.UP * 1.4, color.lightened(0.2), 1.1)
