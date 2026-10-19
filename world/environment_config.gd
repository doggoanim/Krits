class_name EnvironmentConfig
extends Resource
## All lighting / sky / color-grading tunables in one place, same idea as
## PlayerConfig. Duplicate/edit a .tres of this to try a different look
## without touching code — assign it to Main's env_config export in main.tscn.

@export_group("Sun")
@export var sun_color := Color(1.0, 0.95, 0.85)
@export var sun_energy := 1.2
@export var sun_rotation_degrees := Vector3(-50, 30, 0)
@export var sun_shadows := true

@export_group("Sky")
@export var sky_top_color := Color(0.25, 0.45, 0.75)
@export var sky_horizon_color := Color(0.65, 0.72, 0.8)
@export var ground_bottom_color := Color(0.15, 0.13, 0.11)
@export var ground_horizon_color := Color(0.5, 0.48, 0.45)
@export var ambient_energy := 1.0

@export_group("Tonemap / Exposure")
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_FILMIC
@export var exposure := 1.0
@export var white_point := 1.0   ## only matters for the Filmic/ACES tonemappers

@export_group("Glow")
@export var glow_enabled := true
@export var glow_intensity := 0.5
@export var glow_bloom := 0.05
@export var glow_hdr_threshold := 1.0

@export_group("Ambient Occlusion")
@export var ssao_enabled := true
@export var ssao_intensity := 1.5
@export var ssao_radius := 1.0

@export_group("Color Grading")
@export var adjustment_enabled := true
@export var brightness := 1.0
@export var contrast := 1.05
@export var saturation := 1.1
@export var color_correction_lut: Texture   ## optional LUT (Texture2D/Texture3D) for a full custom grade
