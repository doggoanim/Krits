extends Node
## Autoload `GraphicsQuality`: applies the Graphics settings that act on the whole
## renderer rather than on one scene — 3D resolution scale, anti-aliasing,
## positional-light shadows and the water detail switch. Per-environment options
## (sun shadows, SSAO, volumetric fog) are applied by Main alongside each level's
## look, because they combine with what the level's EnvironmentConfig asks for.
##
## To add a global graphics option: add its key to Settings.DEFAULTS, a row in
## settings_screen.tscn, and a line in _apply_all() below.

const WATER_DETAIL_PARAM := &"water_detail"
const MSAA_MODES := {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}
const SHADOW_ATLAS_SIZE := 4096   ## Godot's default for omni/spot light shadows

func _ready() -> void:
	Settings.changed.connect(_on_setting_changed)
	_apply_all()

func _on_setting_changed(key: StringName) -> void:
	if String(key).begins_with("graphics/"):
		_apply_all()

func _apply_all() -> void:
	var vp := get_viewport()
	vp.scaling_3d_scale = clampf(int(Settings.get_value(&"graphics/resolution_scale")) / 100.0, 0.25, 1.0)
	vp.msaa_3d = MSAA_MODES.get(int(Settings.get_value(&"graphics/msaa")), Viewport.MSAA_DISABLED)
	# No shadow atlas = omni/spot lights cast no shadows (the sun is handled by Main).
	vp.positional_shadow_atlas_size = SHADOW_ATLAS_SIZE if Settings.get_value(&"graphics/shadows") else 0
	RenderingServer.global_shader_parameter_set(WATER_DETAIL_PARAM, 1.0 if Settings.get_value(&"graphics/water_detail") else 0.0)
