@tool
class_name CheckpointCrystal
extends Node3D
## (@tool so a checkpoint shows up in the editor viewport.)
## The look of a Spawnpoint (checkpoint): a stone plinth with a floating
## crystal. Pure visuals — Spawnpoint owns the logic and just drives this with
## set_unlocked() / set_active() / flash().
##
##   locked   dull grey-blue crystal, barely glowing, drifting slowly
##   unlocked cyan crystal, glowing, lighting its surroundings, spinning
##   active   (player standing at it) brighter still: travel is available
##   flash    one-off burst of light + particles + a scale pop on activation

const LOCKED_COLOR := Color(0.45, 0.5, 0.64)
const UNLOCKED_COLOR := Color(0.35, 0.95, 1.0)
const STONE_COLOR := Color(0.33, 0.34, 0.4)

const FLOAT_HEIGHT := 1.7
const BOB_AMPLITUDE := 0.12
const CRYSTAL_RADIUS := 0.38
const CRYSTAL_TOP := 0.75
const CRYSTAL_BOTTOM := 0.55
const SHARD_COUNT := 3
const SHARD_ORBIT_RADIUS := 0.78

const WAKE_SPEED := 1.5     ## locked <-> unlocked blend, per second
const ACTIVE_SPEED := 4.0
const FLASH_DECAY := 1.6

@export var light_range := 7.0

var _unlocked := false
var _active := false
var _awake := 0.0           ## 0 = locked look, 1 = unlocked look
var _active_blend := 0.0
var _flash := 0.0
var _t := 0.0

var _core: Node3D
var _orbit: Node3D
var _crystal_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _light: OmniLight3D
var _burst: CPUParticles3D

func _ready() -> void:
	_build_plinth()
	_build_crystal()
	_build_shards()
	_build_light()
	_build_burst()
	_apply()

# ---------------------------------------------------------------- public API

## `animate` = false snaps straight to the state (used when the level loads).
func set_unlocked(unlocked: bool, animate := true) -> void:
	_unlocked = unlocked
	if not animate:
		_awake = 1.0 if unlocked else 0.0
		if is_inside_tree() and _core != null:
			_apply()

## The player is standing at the checkpoint.
func set_active(active: bool) -> void:
	_active = active

## Activation burst. `strength` 1.0 = first discovery, lower = a revisit.
func flash(strength := 1.0) -> void:
	_flash = maxf(_flash, strength)
	if _burst != null:
		_burst.amount = int(lerpf(10.0, 36.0, clampf(strength, 0.0, 1.0)))
		_burst.restart()
		_burst.emitting = true

# --------------------------------------------------------------------- build

func _emissive_material(albedo_darken := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = LOCKED_COLOR.darkened(albedo_darken)
	m.emission_enabled = true
	m.emission = LOCKED_COLOR
	m.roughness = 0.25
	return m

func _mesh(mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _build_plinth() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE_COLOR
	stone.roughness = 0.9
	var base := CylinderMesh.new()
	base.top_radius = 0.8
	base.bottom_radius = 1.0
	base.height = 0.3
	base.radial_segments = 8
	var base_mi := _mesh(base, stone, Vector3.UP * 0.15)
	base_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(base_mi)

	_ring_mat = _emissive_material()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.56
	ring.outer_radius = 0.7
	ring.rings = 24
	ring.ring_segments = 4
	var ring_mi := _mesh(ring, _ring_mat, Vector3.UP * 0.31)
	ring_mi.scale = Vector3(1.0, 0.25, 1.0)
	add_child(ring_mi)

func _build_crystal() -> void:
	_crystal_mat = _emissive_material()
	_core = Node3D.new()
	_core.position.y = FLOAT_HEIGHT
	add_child(_core)
	var top := CylinderMesh.new()
	top.top_radius = 0.0
	top.bottom_radius = CRYSTAL_RADIUS
	top.height = CRYSTAL_TOP
	top.radial_segments = 6
	top.rings = 1
	_core.add_child(_mesh(top, _crystal_mat, Vector3.UP * CRYSTAL_TOP * 0.5))
	var bottom := CylinderMesh.new()
	bottom.top_radius = CRYSTAL_RADIUS
	bottom.bottom_radius = 0.0
	bottom.height = CRYSTAL_BOTTOM
	bottom.radial_segments = 6
	bottom.rings = 1
	_core.add_child(_mesh(bottom, _crystal_mat, Vector3.DOWN * CRYSTAL_BOTTOM * 0.5))

func _build_shards() -> void:
	_orbit = Node3D.new()
	_orbit.position.y = FLOAT_HEIGHT
	add_child(_orbit)
	var shard := CylinderMesh.new()
	shard.top_radius = 0.0
	shard.bottom_radius = 0.08
	shard.height = 0.3
	shard.radial_segments = 4
	shard.rings = 1
	for i in SHARD_COUNT:
		var a := TAU * float(i) / SHARD_COUNT
		var mi := _mesh(shard, _crystal_mat)
		mi.position = Vector3(cos(a), 0.0, sin(a)) * SHARD_ORBIT_RADIUS + Vector3.UP * sin(a * 2.0) * 0.18
		mi.rotation.z = deg_to_rad(18.0)
		_orbit.add_child(mi)

func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.position.y = FLOAT_HEIGHT
	_light.omni_range = light_range
	_light.shadow_enabled = false
	_light.light_color = UNLOCKED_COLOR
	add_child(_light)

func _build_burst() -> void:
	_burst = CPUParticles3D.new()
	_burst.position.y = FLOAT_HEIGHT
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.lifetime = 1.0
	_burst.amount = 36
	_burst.direction = Vector3.UP
	_burst.spread = 180.0
	_burst.initial_velocity_min = 2.0
	_burst.initial_velocity_max = 5.0
	_burst.gravity = Vector3(0.0, -2.5, 0.0)
	_burst.scale_amount_min = 0.5
	_burst.scale_amount_max = 1.2
	var spark := SphereMesh.new()
	spark.radius = 0.05
	spark.height = 0.1
	spark.radial_segments = 6
	spark.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = UNLOCKED_COLOR
	_burst.mesh = spark
	_burst.material_override = mat
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_burst)

# ------------------------------------------------------------------- update

func _process(delta: float) -> void:
	_t += delta
	_awake = move_toward(_awake, 1.0 if _unlocked else 0.0, delta * WAKE_SPEED)
	_active_blend = move_toward(_active_blend, 1.0 if _active else 0.0, delta * ACTIVE_SPEED)
	_flash = move_toward(_flash, 0.0, delta * FLASH_DECAY)
	_core.rotation.y += delta * lerpf(0.4, 1.6, _awake)
	_orbit.rotation.y -= delta * lerpf(0.3, 1.4, _awake)
	_apply()

func _apply() -> void:
	var bob := sin(_t * 1.6) * BOB_AMPLITUDE * lerpf(0.4, 1.0, _awake)
	_core.position.y = FLOAT_HEIGHT + bob
	_core.scale = Vector3.ONE * (1.0 + _flash * 0.3)
	_orbit.position.y = FLOAT_HEIGHT + bob * 0.5
	_orbit.scale = Vector3.ONE * lerpf(0.6, 1.0, _awake)

	var tint := LOCKED_COLOR.lerp(UNLOCKED_COLOR, _awake)
	var shimmer := 0.25 * sin(_t * 3.0) * _awake
	var energy := lerpf(0.25, 2.0, _awake) + 0.7 * _active_blend + 3.0 * _flash + shimmer
	_crystal_mat.albedo_color = tint.darkened(0.35)
	_crystal_mat.emission = tint
	_crystal_mat.emission_energy_multiplier = energy
	_ring_mat.albedo_color = tint.darkened(0.35)
	_ring_mat.emission = tint
	_ring_mat.emission_energy_multiplier = lerpf(0.1, 1.2, _awake) + 1.2 * _active_blend + 2.0 * _flash

	_light.light_color = tint
	_light.light_energy = _awake * (1.0 + 0.8 * _active_blend) + _flash * 4.0
	_light.visible = _light.light_energy > 0.02
