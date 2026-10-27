class_name EnvironmentConfig
extends Resource
## All lighting / sky / color-grading tunables in one place, same idea as
## PlayerConfig. Duplicate/edit a .tres of this to try a different look
## without touching code — assign it to Main's env_config export in main.tscn.
##
## Defaults are tuned for a cartoony, Mario-Odyssey/BOTW-ish look without
## blowing out the exposure: moderate ambient fill so shadows stay soft
## without washing things out, soft shadow edges, punchy-but-not-glaring
## saturation, light AO rather than gritty/realistic. This covers
## lighting and color only — the other half of that look (flatter material
## shading, maybe outlines) is a separate, bigger change to how materials
## are shaded project-wide; ask if you want that too.

@export_group("Sun")
@export var sun_color := Color(1.0, 0.96, 0.85)      ## warm, slightly golden
@export var sun_energy := 0.8
@export var sun_rotation_degrees := Vector3(-60, 35, 0)   ## higher sun = softer, shorter shadows
@export var sun_shadows := true
@export var sun_shadow_blur := 2.5                   ## higher = softer shadow edges (no hard realistic shadows)

@export_group("Sky")
@export var sky_top_color := Color(0.180, 0.365, 0.808)      ## cheerful blue, a bit less saturated than before
@export var sky_horizon_color := Color(0.7, 0.8, 0.9)
@export var ground_bottom_color := Color(0.28, 0.24, 0.19)
@export var ground_horizon_color := Color(0.55, 0.5, 0.4)
@export var ambient_energy := 0.65                   ## fill light so shadows stay soft, without washing everything out
@export var ambient_color := Color(0.92, 0.92, 0.95)      ## near-neutral; kept separate from the sky's blue so it
															## doesn't tint the character/props — only the sky itself is blue

@export_group("Tonemap / Exposure")
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_FILMIC
@export var exposure := 0.8
@export var white_point := 1.0   ## only matters for the Filmic/ACES tonemappers

@export_group("Glow")
@export var glow_enabled := true
@export var glow_intensity := 0.35
@export var glow_bloom := 0.05
@export var glow_hdr_threshold := 1.0                ## lower = more things get a soft glossy glow

@export_group("Ambient Occlusion")
@export var ssao_enabled := true
@export var ssao_intensity := 0.8                    ## light touch — heavy AO reads as gritty/realistic, not cartoony
@export var ssao_radius := 0.8

@export_group("Volumetric Fog")
## Godot's native volumetric fog — turned on, this is what actually produces
## visible sun shafts/god rays through trees and gaps: the fog scatters the
## sun's own light, so it lights up brightly wherever nothing's blocking the
## sun and stays dark in shadow, reading as visible beams rather than a flat
## haze. Off by default: density/length that read as a subtle shaft in one
## scene can read as a thick haze over everything in another depending on
## exposure/scale, so this needs hand-tuning per environment rather than a
## one-size-fits-all default — flip volumetric_fog_enabled on and start from
## a low density (0.003-0.01), raising it a little at a time.
@export var volumetric_fog_enabled := false
@export var volumetric_fog_density := 0.006         ## higher = thicker haze overall, muddies the shaft look past a point
@export var volumetric_fog_albedo := Color(1.0, 1.0, 1.0)   ## tints the fog itself, independent of the sun's own color
@export var volumetric_fog_anisotropy := 0.3        ## forward-scattering bias — higher = tighter, more directional-looking shafts
@export var volumetric_fog_length := 48.0           ## how far the fog volume extends from the camera
@export var volumetric_fog_gi_inject := 0.3         ## how much the fog also picks up bounced/ambient light, not just the sun directly
@export var sun_volumetric_fog_energy := 1.0        ## how strongly the sun itself lights up the fog — separate
													  ## from sun_energy (which only affects regular surface lighting)

@export_group("Color Grading")
@export var adjustment_enabled := true
@export var brightness := 0.85
@export var contrast := 1.0                          ## kept neutral so blacks don't crush — cartoony reads as bright, not punchy-dark
@export var saturation := 1.45                        ## the main "cartoony" knob — push further for even more candy-colored, lower toward 1.0 for muted
@export var color_correction_lut: Texture   ## optional LUT (Texture2D/Texture3D) for a full custom grade
