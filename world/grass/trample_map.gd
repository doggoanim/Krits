class_name TrampleMap
extends Node3D
## Publishes a small top-down "trample map" every frame that grass shaders
## read to bend blades away from nearby movers — the classic BotW-style
## interactive-grass trick: render mover positions into a tiny top-down
## texture, then sample that texture back in the grass vertex shader.
##
## Anything that should press grass down adds a TrampleMarker child (see
## trample_marker.gd) — this node never needs to know what those movers
## are. Grass materials never need a direct reference either: everything
## is wired through the `trample_map` / `trample_center` / `trample_area_size`
## global shader uniforms this node publishes, so any grass using
## grass.gdshader picks it up automatically.

const TRAMPLE_LAYER := 1 << 19   ## visual layer 20 — see TrampleMarker
const MAP_RESOLUTION := 256
const CAMERA_HEIGHT := 20.0

@export var area_size := 24.0    ## world units the map covers, centered on `follow_target`
@export var follow_target: Node3D

var _viewport: SubViewport
var _camera: Camera3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(MAP_RESOLUTION, MAP_RESOLUTION)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	add_child(_viewport)

	# Forced to solid black regardless of the level's actual sky/lighting:
	# untouched grass must read trample_amount = 0, and the marker itself is
	# unshaded white, so neither depends on the real environment at all.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_energy = 0.0

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = area_size
	_camera.near = 0.1
	_camera.far = CAMERA_HEIGHT + 5.0
	_camera.cull_mask = TRAMPLE_LAYER
	_camera.environment = env
	_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_camera.current = true
	_viewport.add_child(_camera)

	RenderingServer.global_shader_parameter_set(&"trample_area_size", area_size)


func _process(_delta: float) -> void:
	var center := follow_target.global_position if follow_target else global_position
	_camera.global_position = Vector3(center.x, center.y + CAMERA_HEIGHT, center.z)
	RenderingServer.global_shader_parameter_set(&"trample_center", center)
	RenderingServer.global_shader_parameter_set(&"trample_map", _viewport.get_texture())
