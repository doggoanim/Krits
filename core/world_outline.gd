class_name WorldOutline
extends Node
## Optional whole-frame depth/normal edge-detection outline, drawn over
## EVERYTHING the camera sees at once (terrain, props, buildings, ...) —
## unlike OutlineSystem (core/outline_system.gd), which only outlines meshes
## explicitly marked via OutlineSystem.mark(). This needs no marking at all:
## it reads the Forward+ renderer's own screen color, depth, and
## normal/roughness buffers (shading/world_outline.gdshader, via the
## hint_screen_texture / hint_depth_texture / hint_normal_roughness_texture
## shader hints) through a single oversized quad parented directly to the
## active camera, and darkens any pixel where depth or surface normal jumps
## sharply between it and its neighbors.
##
## This is NOT wired into main.gd — add_child one and call follow() to try
## it; call follow(null) to turn it back off. Does not replace or touch
## OutlineSystem, the game's actual character-outline system.
##
## REQUIRES the Forward+ renderer (Project Settings / Rendering / Renderer /
## Rendering Method = forward_plus) — hint_normal_roughness_texture doesn't
## exist on Mobile or Compatibility, and the shader will fail to compile
## without it.
##
## Inspired by the depth/normal edge-detection idea in "3D PixelArt Tutorial"
## (pixelagegames on itch.io), which builds the same effect as a Compositor
## + compute shader; this uses Godot's older, much simpler screen/depth/
## normal-roughness shader hints instead, for the same result with none of
## the RenderingDevice boilerplate.

@export var outline_color := Color.BLACK
@export_range(0.5, 4.0, 0.1) var outline_width_px := 1.0    ## how many pixels apart the compared samples are
@export_range(0.0, 5.0, 0.1) var depth_sensitivity := 1.0   ## higher = outlines appear on shallower depth steps too
@export_range(0.0, 2.0, 0.1) var normal_sensitivity := 0.4  ## higher = outlines appear on shallower angle changes too

var _quad: MeshInstance3D
var _material: ShaderMaterial

func _ready() -> void:
	var mesh := QuadMesh.new()
	# Deliberately huge: placed just past the camera's near plane (see
	# follow()), this guarantees full coverage of the view at any FOV without
	# having to compute the exact frustum size for that distance.
	mesh.size = Vector2(1000.0, 1000.0)

	_material = ShaderMaterial.new()
	_material.shader = preload("res://shading/world_outline.gdshader")
	_apply_style()

	_quad = MeshInstance3D.new()
	_quad.mesh = mesh
	_quad.material_override = _material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.visible = false   ## shown once follow() parents it to a real camera

func _apply_style() -> void:
	_material.set_shader_parameter(&"outline_color", outline_color)
	_material.set_shader_parameter(&"outline_width_px", outline_width_px)
	_material.set_shader_parameter(&"depth_sensitivity", depth_sensitivity)
	_material.set_shader_parameter(&"normal_sensitivity", normal_sensitivity)

## Parents the effect's quad directly to `camera` so it always sits right in
## front of it, or hides it if `camera` is null. Call again if the active
## camera ever changes (e.g. a cutscene camera taking over) — same
## convention as OutlineSystem.follow().
func follow(camera: Camera3D) -> void:
	if _quad.get_parent() != null:
		_quad.get_parent().remove_child(_quad)
	if camera == null:
		_quad.visible = false
		return
	camera.add_child(_quad)
	_quad.position = Vector3(0.0, 0.0, -(camera.near + 0.05))
	_quad.visible = true
