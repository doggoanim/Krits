class_name TimeOfDay
extends Node
## Drop one into an OUTDOOR level (Chesburg has one) and the sun, moon, sky,
## ambient light and haze follow WorldClock's hour: golden dawn, bright day,
## orange dusk, a blue moonlit night with stars.
##
## It does not own the lights — Main builds the one Sun / WorldEnvironment pair
## for the whole game (see main.gd _build_environment) — it just re-tunes them
## every frame, on top of whatever EnvironmentConfig the level loaded. Because
## the node lives in the level, it stops the moment you walk into a house and
## Main's interior grading takes over untouched.
##
## All the looks are the KEYS_* tables below: [hour, value] stops, blended
## linearly and wrapping at midnight. Add a stop (or change a colour) to
## re-grade a time of day — nothing else needs to change.

@export var sun_yaw := 35.0                      ## compass heading the sun rises on (degrees)
@export var sun_sweep := 140.0                   ## how far (degrees) it travels sideways over the day
@export_range(10.0, 85.0) var sun_max_elevation := 62.0
@export_range(10.0, 85.0) var moon_max_elevation := 42.0
@export_range(0.0, 1.0) var night_lantern := 1.0   ## how much brighter the player's hip lantern is at night (1 = same as the level's own boost)
@export var night_lantern_boost := 2.2

# [hour, Color or float]. Hours wrap, so the last stop blends back into the first.
const SUN_COLOR := [
	[0.0, Color(0.50, 0.62, 1.0)], [5.0, Color(0.50, 0.62, 1.0)], [6.5, Color(1.0, 0.58, 0.32)],
	[8.5, Color(1.0, 0.93, 0.78)], [16.0, Color(1.0, 0.93, 0.78)], [18.0, Color(1.0, 0.52, 0.28)],
	[19.8, Color(0.50, 0.62, 1.0)],
]
const SUN_ENERGY := [
	[0.0, 0.22], [5.0, 0.22], [6.5, 0.55], [8.5, 1.2], [16.0, 1.2], [18.0, 0.65], [19.8, 0.22],
]
const SKY_TOP := [
	[0.0, Color(0.015, 0.03, 0.11)], [5.0, Color(0.03, 0.05, 0.18)], [6.5, Color(0.30, 0.32, 0.62)],
	[8.5, Color(0.04, 0.32, 0.92)], [16.0, Color(0.04, 0.32, 0.92)], [18.0, Color(0.33, 0.28, 0.60)],
	[19.8, Color(0.03, 0.05, 0.18)],
]
const SKY_HORIZON := [
	[0.0, Color(0.05, 0.08, 0.20)], [5.0, Color(0.07, 0.10, 0.24)], [6.5, Color(1.0, 0.62, 0.45)],
	[8.5, Color(0.55, 0.88, 1.0)], [16.0, Color(0.55, 0.88, 1.0)], [18.0, Color(1.0, 0.50, 0.35)],
	[19.8, Color(0.08, 0.11, 0.26)],
]
const CLOUD_LIGHT := [
	[0.0, Color(0.30, 0.36, 0.58)], [5.0, Color(0.30, 0.36, 0.58)], [6.5, Color(1.0, 0.76, 0.62)],
	[8.5, Color(1, 1, 1)], [16.0, Color(1, 1, 1)], [18.0, Color(1.0, 0.70, 0.55)], [19.8, Color(0.30, 0.36, 0.58)],
]
const CLOUD_SHADOW := [
	[0.0, Color(0.06, 0.08, 0.18)], [5.0, Color(0.06, 0.08, 0.18)], [6.5, Color(0.58, 0.42, 0.62)],
	[8.5, Color(0.50, 0.64, 0.90)], [16.0, Color(0.50, 0.64, 0.90)], [18.0, Color(0.55, 0.38, 0.58)],
	[19.8, Color(0.06, 0.08, 0.18)],
]
const AMBIENT_COLOR := [
	[0.0, Color(0.26, 0.32, 0.60)], [5.0, Color(0.26, 0.32, 0.60)], [6.5, Color(0.80, 0.66, 0.70)],
	[8.5, Color(0.76, 0.84, 1.0)], [16.0, Color(0.76, 0.84, 1.0)], [18.0, Color(0.85, 0.65, 0.65)],
	[19.8, Color(0.26, 0.32, 0.60)],
]
const AMBIENT_ENERGY := [
	[0.0, 0.5], [5.0, 0.5], [6.5, 0.6], [8.5, 0.7], [16.0, 0.7], [18.0, 0.6], [19.8, 0.5],
]
const HAZE_COLOR := [
	[0.0, Color(0.07, 0.09, 0.19)], [5.0, Color(0.08, 0.10, 0.22)], [6.5, Color(0.95, 0.72, 0.62)],
	[8.5, Color(0.78, 0.88, 0.96)], [16.0, Color(0.78, 0.88, 0.96)], [18.0, Color(0.95, 0.66, 0.55)],
	[19.8, Color(0.08, 0.10, 0.22)],
]

var _env: Environment
var _sun: DirectionalLight3D
var _day_lantern_boost := -1.0

func _process(_delta: float) -> void:
	if _sun == null or not is_instance_valid(_sun):
		_sun = get_tree().get_first_node_in_group(&"sun") as DirectionalLight3D
	if _env == null:
		_env = _find_environment()
	if _sun == null or _env == null:
		return
	var h := WorldClock.hour
	_apply_sun(h)
	_apply_ambient(h)
	_apply_sky(h)
	_apply_lantern()

func _find_environment() -> Environment:
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var env := (node as WorldEnvironment).environment
		if env != null:
			return env
	return null

# --- sun / moon -----------------------------------------------------------

func _apply_sun(h: float) -> void:
	# One light plays both parts: the sun from 06:00 to 18:00, then the moon
	# takes the same seat on a lower, bluer arc (the colour/energy tables do the
	# switch, the arc below just keeps it above the horizon).
	var daytime := h >= 6.0 and h < 18.0
	var progress: float = (h - 6.0) / 12.0 if daytime else fposmod(h - 18.0, 24.0) / 12.0
	var peak := sun_max_elevation if daytime else moon_max_elevation
	var elevation := maxf(sin(progress * PI) * peak, 7.0)
	_sun.rotation_degrees = Vector3(-elevation, sun_yaw + (progress - 0.5) * sun_sweep, 0.0)
	_sun.light_color = _sample_color(SUN_COLOR, h)
	_sun.light_energy = _sample_float(SUN_ENERGY, h)

func _apply_ambient(h: float) -> void:
	_env.ambient_light_color = _sample_color(AMBIENT_COLOR, h)
	_env.ambient_light_energy = _sample_float(AMBIENT_ENERGY, h)
	_env.fog_light_color = _sample_color(HAZE_COLOR, h)

# --- sky ------------------------------------------------------------------

func _apply_sky(h: float) -> void:
	if _env.sky == null:
		return
	var top := _sample_color(SKY_TOP, h)
	var horizon := _sample_color(SKY_HORIZON, h)
	var shader_mat := _env.sky.sky_material as ShaderMaterial
	if shader_mat != null:
		shader_mat.set_shader_parameter(&"top_color", top)
		shader_mat.set_shader_parameter(&"horizon_color", horizon)
		shader_mat.set_shader_parameter(&"cloud_light", _sample_color(CLOUD_LIGHT, h))
		shader_mat.set_shader_parameter(&"cloud_shadow", _sample_color(CLOUD_SHADOW, h))
		shader_mat.set_shader_parameter(&"star_strength", WorldClock.night_amount())
		# The moon sits wherever the light is: the light's local +Z points toward it.
		shader_mat.set_shader_parameter(&"body_dir", _sun.global_transform.basis.z)
		shader_mat.set_shader_parameter(&"body_strength", WorldClock.night_amount())
		return
	var proc := _env.sky.sky_material as ProceduralSkyMaterial
	if proc != null:
		proc.sky_top_color = top
		proc.sky_horizon_color = horizon
		proc.ground_horizon_color = horizon * 0.8

func _apply_lantern() -> void:
	# The player's hip lantern is dim in daylight (the level asks for 0.3x);
	# push it up as it gets dark so it actually lights the way.
	if _day_lantern_boost < 0.0:
		_day_lantern_boost = HipLantern.level_boost
	HipLantern.level_boost = lerpf(_day_lantern_boost, night_lantern_boost, WorldClock.night_amount() * night_lantern)

# --- keyframe tables ------------------------------------------------------

static func _sample_float(keys: Array, h: float) -> float:
	var span := _span(keys, h)
	return lerpf(span[0][1], span[1][1], span[2])

static func _sample_color(keys: Array, h: float) -> Color:
	var span := _span(keys, h)
	return (span[0][1] as Color).lerp(span[1][1] as Color, span[2])

## The two stops around hour `h` and how far between them it is (0..1); wraps midnight.
static func _span(keys: Array, h: float) -> Array:
	var last := keys.size() - 1
	for i in last:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if h >= a[0] and h < b[0]:
			return [a, b, (h - a[0]) / maxf(b[0] - a[0], 0.0001)]
	# Past the last stop: blend toward the first one, a day later.
	var a_last: Array = keys[last]
	var b_first: Array = keys[0]
	var end: float = b_first[0] + 24.0
	var hh := h if h >= a_last[0] else h + 24.0
	return [a_last, b_first, (hh - a_last[0]) / maxf(end - a_last[0], 0.0001)]
