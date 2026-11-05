class_name CharacterFillLight
extends DirectionalLight3D
## A soft, shadowless fill that lights ONLY characters (never the ground or
## walls), shining from the side opposite the sun so the shadowed side of a
## character isn't a flat tint. Fixed in the world — it doesn't follow the
## camera — so a character's lighting doesn't change as you orbit.
##
## Why a directional light restricted to a render layer, instead of the
## OmniLight3D this used to be: an omni light lights everything in its radius
## (the ground and walls glowed around the player even with the lantern off),
## and a light sitting right next to the camera produced a blocky, screen-tile
## shaped disc where its edge crossed the view.
##
## Characters opt in by being on ModelUtil.CHARACTER_LIGHT_LAYER, which
## ModelUtil.apply_cel_shading() does for every model it shades.
## Added by Player next to the lantern.

@export var fill_energy := 0.4
@export var fill_color := Color(0.85, 0.92, 1.0)   ## slightly cool white
@export_range(0.0, 1.0, 0.05) var downward_tilt := 0.3   ## how much the fill points down rather than level

var _sun: Node3D   ## the level sun (group "sun", set up by Main)

func _ready() -> void:
	top_level = true   # world-space: oriented by script, not by the player
	light_color = fill_color
	light_energy = fill_energy
	light_cull_mask = ModelUtil.CHARACTER_LIGHT_LAYER   # characters only
	light_specular = 0.0
	light_volumetric_fog_energy = 0.0
	sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # never touches the sky shader
	shadow_enabled = false

func _process(_delta: float) -> void:
	if _sun == null or not is_instance_valid(_sun):
		_sun = get_tree().get_first_node_in_group(&"sun") as Node3D
	# Opposite the sun's travel direction, flattened, with a slight downward tilt.
	var sun_forward := -_sun.global_basis.z if _sun != null else Vector3.FORWARD
	var dir := Vector3(-sun_forward.x, 0.0, -sun_forward.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
	dir = (dir + Vector3.DOWN * downward_tilt).normalized()
	global_basis = Basis.looking_at(dir, Vector3.UP)
