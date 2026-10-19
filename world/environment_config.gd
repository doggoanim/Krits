class_name EnvironmentConfig
extends Resource
## All lighting / sky / color-grading tunables in one place, same idea as
## PlayerConfig. Duplicate/edit a .tres of this to try a different look
## without touching code — assign it to Main's env_config export in main.tscn.
##
## Defaults are tuned for a bright, cartoony, Mario-Odyssey/BOTW-ish look:
## high ambient fill so shadows never go pitch black, soft shadow edges,
## punchy saturation, light AO rather than gritty/realistic. This covers
## lighting and color only — the other half of that look (flatter material
## shading, maybe outlines) is a separate, bigger change to how materials
## are shaded project-wide; ask if you want that too.

@export_group("Sun")
@export var sun_color := Color(1.0, 0.96, 0.85)      ## warm, bright, slightly golden
@export var sun_energy := 1.35
@export var sun_rotation_degrees := Vector3(-60, 35, 0)   ## higher sun = softer, shorter shadows
@export var sun_shadows := true
@export var sun_shadow_blur := 2.5                   ## higher = softer shadow edges (no hard realistic shadows)

@export_group("Sky")
@export var sky_top_color := Color(0.25, 0.6, 0.95)      ## vivid, cheerful blue
@export var sky_horizon_color := Color(0.78, 0.88, 0.97) ## bright near the horizon, not hazy/dim
@export var ground_bottom_color := Color(0.3, 0.26, 0.2)
@export var ground_horizon_color := Color(0.6, 0.55, 0.42)
@export var ambient_energy := 1.3                    ## strong fill light so shadows stay soft, never pitch black

@export_group("Tonemap / Exposure")
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_FILMIC
@export var exposure := 1.1
@export var white_point := 1.0   ## only matters for the Filmic/ACES tonemappers

@export_group("Glow")
@export var glow_enabled := true
@export var glow_intensity := 0.6
@export var glow_bloom := 0.08
@export var glow_hdr_threshold := 0.85               ## lower = more things get a soft glossy glow

@export_group("Ambient Occlusion")
@export var ssao_enabled := true
@export var ssao_intensity := 0.8                    ## light touch — heavy AO reads as gritty/realistic, not cartoony
@export var ssao_radius := 0.8

@export_group("Color Grading")
@export var adjustment_enabled := true
@export var brightness := 1.05
@export var contrast := 1.0                          ## kept neutral so blacks don't crush — cartoony reads as bright, not punchy-dark
@export var saturation := 1.3                         ## the main "cartoony" knob — push further (1.4-1.5) for even more candy-colored
@export var color_correction_lut: Texture   ## optional LUT (Texture2D/Texture3D) for a full custom grade
