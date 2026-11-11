class_name ZoneStreamer
extends Node
## Streams WorldZone children in and out by distance to the player and blends
## the distance haze between zone moods. Add it (plus WorldZone nodes) under an
## open-world level root; Main hands it the player and the Environment.
##
## Zones load without a loading screen. Interiors and dungeons stay
## door-swapped levels.

## Haze density outside every zone's mood. Higher = the lake fades out sooner,
## so the town reads as a small island. Negative keeps the level's own value.
@export var base_haze_density := 0.012

const CHECK_INTERVAL := 0.25
const FOG_BLEND_SPEED := 1.5

var _player: Node3D
var _env: Environment
var _zones: Array[WorldZone] = []
var _base_color: Color
var _base_density: float
var _timer := 0.0

func setup(player: Node3D, env: Environment) -> void:
	_player = player
	_env = env
	_base_color = env.fog_light_color
	_base_density = env.fog_density if base_haze_density < 0.0 else base_haze_density
	_zones.clear()
	for n in get_parent().find_children("*", "WorldZone", true, false):
		_zones.append(n as WorldZone)
	_update_loading()

func _process(delta: float) -> void:
	if _player == null or _env == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHECK_INTERVAL
		_update_loading()
	_blend_mood(delta)

func _update_loading() -> void:
	var p := _player.global_position
	for z in _zones:
		var d := Vector2(p.x - z.global_position.x, p.z - z.global_position.z).length()
		if d <= z.load_radius:
			z.load_content()
		elif d >= z.unload_radius:
			z.unload_content()

func _blend_mood(delta: float) -> void:
	var color := _base_color
	var density := _base_density
	var p := _player.global_position
	for z in _zones:
		if z.mood == null:
			continue
		var w := z.mood_weight(p)
		color = color.lerp(z.mood.haze_color, w)
		density = lerpf(density, z.mood.haze_density, w)
	var t := clampf(delta * FOG_BLEND_SPEED, 0.0, 1.0)
	_env.fog_light_color = _env.fog_light_color.lerp(color, t)
	_env.fog_density = lerpf(_env.fog_density, density, t)
