class_name WellAtmosphere
extends Node
## Depth-driven mood for the well, layered on top of the level's EnvironmentConfig
## (world/well_lighting.tres): the deeper the player goes, the more the air and
## fog shift from the mossy green of the shaft, through damp blue, to the
## aqua-gold of the spirits' pool, and the fog thickens. Close to the spirits
## the whole place brightens and their light swells. The sunbeam down the shaft
## also sways and flickers a little, as if clouds drift over the opening.
##
## Everything is editable in the Inspector (the gradients run from the top of the
## well at 0.0 to the bottom at 1.0). Reads the live Environment each frame, so
## it works with whatever the Graphics settings turn on or off.

@export_group("Depth")
@export var top_y := 3.0           ## player height that counts as "top of the well"
@export var bottom_y := -24.0      ## ... and "bottom"
@export_range(0.0, 1.0, 0.05) var tint_strength := 0.55   ## how far the gradients pull ambient/fog from the base look
@export var ambient_gradient: Gradient
@export var fog_gradient: Gradient
@export var fog_density_top := 0.85    ## x the base fog density at the top
@export var fog_density_bottom := 1.7  ## ... and at the bottom

@export_group("Spirits")
@export var spirits_path: NodePath = ^"../WaterSpirits"
@export var reveal_far := 20.0         ## brightening begins this close to the spirits
@export var reveal_near := 5.0         ## ... and is complete this close
@export var reveal_light_boost := 2.2  ## x extra on the spirits' own glow light
@export var reveal_ambient_boost := 0.35   ## extra ambient energy at full reveal
@export var reveal_color := Color(0.6, 1.0, 0.9)

@export_group("Shaft")
@export var shaft_path: NodePath = ^"../WellShaft"
@export_range(0.0, 0.6, 0.01) var shaft_flicker := 0.16
@export_range(0.0, 6.0, 0.1) var shaft_sway_degrees := 1.6

const SMOOTH := 2.5

var _env: Environment
var _base_ambient: Color
var _base_ambient_energy := 1.0
var _base_fog_albedo: Color
var _base_fog_density := 0.0
var _depth := 0.0       ## smoothed 0..1
var _reveal := 0.0      ## smoothed 0..1
var _spirits: Node3D
var _spirit_glow: OmniLight3D
var _spirit_glow_base := 1.0
var _shaft: SpotLight3D
var _shaft_base_energy := 1.0
var _shaft_base_basis := Basis.IDENTITY
var _t := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_make_default_gradients()
	_spirits = get_node_or_null(spirits_path) as Node3D
	if _spirits != null:
		_spirit_glow = _spirits.get_node_or_null("Glow") as OmniLight3D
		if _spirit_glow != null:
			_spirit_glow_base = _spirit_glow.light_energy
	_shaft = get_node_or_null(shaft_path) as SpotLight3D
	if _shaft != null:
		_shaft_base_energy = _shaft.light_energy
		_shaft_base_basis = _shaft.basis
	# The level's own look is applied by Main as this level loads; read it once that has happened.
	await get_tree().process_frame
	await get_tree().process_frame
	_env = get_viewport().world_3d.environment if get_viewport().world_3d != null else null
	if _env != null:
		_capture_base()

func _exit_tree() -> void:
	if _env != null:   # leave the shared Environment as the level's own look had it
		_env.ambient_light_color = _base_ambient
		_env.ambient_light_energy = _base_ambient_energy
		_env.volumetric_fog_albedo = _base_fog_albedo
		_env.volumetric_fog_density = _base_fog_density

func _capture_base() -> void:
	_base_ambient = _env.ambient_light_color
	_base_ambient_energy = _env.ambient_light_energy
	_base_fog_albedo = _env.volumetric_fog_albedo
	_base_fog_density = _env.volumetric_fog_density

func _make_default_gradients() -> void:
	if ambient_gradient == null:
		ambient_gradient = Gradient.new()
		ambient_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		ambient_gradient.colors = PackedColorArray([
			Color(0.50, 0.78, 0.62),   # mossy green shaft
			Color(0.42, 0.62, 0.82),   # damp blue middle
			Color(0.55, 0.82, 0.78)])  # aqua pool
	if fog_gradient == null:
		fog_gradient = Gradient.new()
		fog_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		fog_gradient.colors = PackedColorArray([
			Color(0.55, 0.85, 0.7),
			Color(0.45, 0.65, 0.9),
			Color(0.6, 0.95, 0.9)])

func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var k := 1.0 - exp(-SMOOTH * delta)
	var depth_target := clampf(inverse_lerp(top_y, bottom_y, player.global_position.y), 0.0, 1.0)
	_depth = lerpf(_depth, depth_target, k)
	var reveal_target := 0.0
	if _spirits != null and is_instance_valid(_spirits) and not Game.flag(&"picked_well_water_spirits"):
		reveal_target = smoothstep(reveal_far, reveal_near, player.global_position.distance_to(_spirits.global_position))
	_reveal = lerpf(_reveal, reveal_target, k)
	_apply_environment()
	_apply_spirit_glow()
	_apply_shaft()

func _apply_environment() -> void:
	if _env == null:
		return
	var amb := ambient_gradient.sample(_depth).lerp(reveal_color, _reveal * 0.5)
	var fog := fog_gradient.sample(_depth).lerp(reveal_color, _reveal * 0.6)
	_env.ambient_light_color = _base_ambient.lerp(amb, tint_strength)
	_env.ambient_light_energy = _base_ambient_energy + reveal_ambient_boost * _reveal
	_env.volumetric_fog_albedo = _base_fog_albedo.lerp(fog, tint_strength)
	_env.volumetric_fog_density = _base_fog_density * lerpf(fog_density_top, fog_density_bottom, _depth) * (1.0 - 0.3 * _reveal)

func _apply_spirit_glow() -> void:
	if _spirit_glow != null and is_instance_valid(_spirit_glow):
		_spirit_glow.light_energy = _spirit_glow_base * (1.0 + reveal_light_boost * _reveal)

## Slow wandering flicker + sway, from a few incommensurate sines (no state needed).
func _apply_shaft() -> void:
	if _shaft == null:
		return
	var n := 0.5 * sin(_t * 0.7) + 0.3 * sin(_t * 1.9 + 1.3) + 0.2 * sin(_t * 4.1 + 0.4)
	_shaft.light_energy = _shaft_base_energy * (1.0 + shaft_flicker * n)
	var sway := deg_to_rad(shaft_sway_degrees)
	_shaft.basis = _shaft_base_basis * Basis.from_euler(Vector3(
			sin(_t * 0.31) * sway, 0.0, sin(_t * 0.23 + 1.0) * sway))
