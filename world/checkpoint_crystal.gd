@tool
class_name CheckpointCrystal
extends Node3D
## (@tool so a checkpoint shows up in the editor viewport.)
## The look of a Spawnpoint (checkpoint), in a stylized hand-painted style: a
## big faceted crystal floating in the air with a few shards circling it, a
## soft glow and a few drifting motes — nothing on the ground. Pure visuals —
## Spawnpoint owns the logic and just drives this with set_unlocked() /
## set_active() / flash().
##
##   locked   dull grey-blue crystal, barely glowing, drifting slowly
##   unlocked berry-blue crystal, glowing, lighting its surroundings, spinning
##   active   (player standing at it) brighter still: travel is available
##   flash    one-off burst of light + sparks + a scale pop on activation
##
## Shapes come from LowPoly, the painted look from shading/painted_crystal.gdshader.

const CRYSTAL_SHADER: Shader = preload("res://shading/painted_crystal.gdshader")

const LOCKED_COLOR := Color(0.5, 0.55, 0.7)
const UNLOCKED_COLOR := Color8(0, 138, 255)   ## the blueberry bush's berry blue (#008AFF, from its palette texture)

const FLOAT_HEIGHT := 1.9
const BOB_AMPLITUDE := 0.12
const SHARD_COUNT := 3
const SHARD_ORBIT_RADIUS := 0.85
const GLOW_SIZE := 3.4

const WAKE_SPEED := 1.5     ## locked <-> unlocked blend, per second
const ACTIVE_SPEED := 4.0
const FLASH_DECAY := 1.6

@export var light_range := 7.0

static var _glow_texture: GradientTexture2D

var _unlocked := false
var _active := false
var _awake := 0.0           ## 0 = locked look, 1 = unlocked look
var _active_blend := 0.0
var _flash := 0.0
var _t := 0.0

var _core: Node3D
var _orbit: Node3D
var _crystal_mat: ShaderMaterial
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _burst: CPUParticles3D
var _motes: CPUParticles3D

func _ready() -> void:
	_crystal_mat = ShaderMaterial.new()
	_crystal_mat.shader = CRYSTAL_SHADER
	_build_core()
	_build_shards()
	_build_glow()
	_build_light()
	_build_burst()
	_build_motes()
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

func _seed() -> int:
	return 1 if not is_inside_tree() else absi(hash(global_position.snapped(Vector3.ONE * 0.1)))

func _mesh_instance(mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _build_core() -> void:
	_core = Node3D.new()
	_core.position.y = FLOAT_HEIGHT
	add_child(_core)
	var mesh := LowPoly.crystal(0.3, 0.55, 0.5, 0.45, 6, _seed() + 3)
	_core.add_child(_mesh_instance(mesh, _crystal_mat, Vector3(0.0, -0.27, 0.0)))

func _build_shards() -> void:
	_orbit = Node3D.new()
	_orbit.position.y = FLOAT_HEIGHT
	add_child(_orbit)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed() + 29
	for i in SHARD_COUNT:
		var a := TAU * float(i) / SHARD_COUNT
		var mesh := LowPoly.crystal(0.06, 0.08, 0.14, 0.08, 4, rng.randi())
		var mi := _mesh_instance(mesh, _crystal_mat,
				Vector3(cos(a), 0.0, sin(a)) * SHARD_ORBIT_RADIUS + Vector3.UP * sin(a * 2.0) * 0.2)
		mi.rotation = Vector3(0.0, a, deg_to_rad(20.0))
		_orbit.add_child(mi)

## A soft additive halo behind the crystal that always faces the camera.
func _build_glow() -> void:
	if _glow_texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = g
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
		_glow_texture.width = 128
		_glow_texture.height = 128
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_mat.albedo_texture = _glow_texture
	_glow_mat.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * GLOW_SIZE
	var mi := _mesh_instance(quad, _glow_mat, Vector3(0.0, FLOAT_HEIGHT, 0.0))
	add_child(mi)

func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.position.y = FLOAT_HEIGHT
	_light.omni_range = light_range
	_light.shadow_enabled = false
	_light.light_color = UNLOCKED_COLOR
	add_child(_light)

## One-shot spark burst on activation.
func _build_burst() -> void:
	_burst = _make_sparks(36, 1.0, true)
	_burst.explosiveness = 1.0
	_burst.direction = Vector3.UP
	_burst.spread = 180.0
	_burst.initial_velocity_min = 2.0
	_burst.initial_velocity_max = 5.0
	_burst.gravity = Vector3(0.0, -2.5, 0.0)
	_burst.position.y = FLOAT_HEIGHT
	add_child(_burst)

## Slow motes drifting up around an unlocked checkpoint.
func _build_motes() -> void:
	_motes = _make_sparks(10, 3.0, false)
	_motes.direction = Vector3.UP
	_motes.spread = 25.0
	_motes.initial_velocity_min = 0.25
	_motes.initial_velocity_max = 0.6
	_motes.gravity = Vector3.ZERO
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 1.1
	_motes.position.y = 0.5
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 0.9
	add_child(_motes)

func _make_sparks(amount: int, lifetime: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = one_shot
	p.amount = amount
	p.lifetime = lifetime
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var spark := QuadMesh.new()
	spark.size = Vector2.ONE * 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = UNLOCKED_COLOR.lightened(0.5)
	p.mesh = spark
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

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
	var shimmer := 0.12 * sin(_t * 3.0) * _awake
	_crystal_mat.set_shader_parameter(&"tint", tint)
	_crystal_mat.set_shader_parameter(&"glow", lerpf(0.2, 1.0, _awake) + 0.5 * _active_blend + 2.0 * _flash + shimmer)

	var halo := lerpf(0.12, 0.5, _awake) + 0.3 * _active_blend + 0.6 * _flash
	_glow_mat.albedo_color = Color(tint, clampf(halo, 0.0, 1.0))
	_motes.emitting = _awake > 0.5

	_light.light_color = tint
	_light.light_energy = _awake * (1.0 + 0.8 * _active_blend) + _flash * 4.0
	_light.visible = _light.light_energy > 0.02
