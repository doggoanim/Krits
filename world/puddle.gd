class_name Puddle
extends MeshInstance3D
## A small flat patch of still water on the floor, drawn with the game's water
## shader (calm: no waves, no foam), so it catches the same wave-line and
## sparkle look as bigger water. Settles onto the floor below its position.

@export var puddle_size := Vector2(1.6, 1.2)
@export var shallow_color := Color(0.16, 0.42, 0.5, 0.75)
@export var deep_color := Color(0.06, 0.2, 0.3, 0.85)
@export var snap_to_ground := true
@export_flags_3d_physics var ground_mask := 1

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = puddle_size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/water/water.gdshader")
	mat.set_shader_parameter(&"shallow_color", shallow_color)
	mat.set_shader_parameter(&"deep_color", deep_color)
	mat.set_shader_parameter(&"wave_height", 0.0)
	mat.set_shader_parameter(&"texture_strength", 0.0)
	mat.set_shader_parameter(&"foam_width", 0.0)
	mat.set_shader_parameter(&"line_strength", 0.25)
	mat.set_shader_parameter(&"line_scale", 3.0)
	mat.set_shader_parameter(&"line_speed", 0.15)
	mat.set_shader_parameter(&"sparkle_strength", 0.4)
	mat.set_shader_parameter(&"color_bands", 1.0)
	plane.material = mat
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if snap_to_ground:
		await get_tree().physics_frame
		await get_tree().physics_frame
		var space := get_world_3d().direct_space_state
		var from := global_position + Vector3.UP * 1.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0, ground_mask))
		if not hit.is_empty():
			global_position = hit.position + Vector3.UP * 0.02
