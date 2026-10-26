@tool
extends Terrain3D
## Sandbox-only helper for trying out Terrain3D with a stepped/terraced
## "stacked slab" look (grass-cap-on-dirt-layer cliffs, like Deepwoken)
## instead of smooth rolling heightmap terrain. Lives entirely in
## terrain3d_test.tscn, separate from the real game world (hometown.tscn
## etc.) — nothing here is wired into gameplay yet.
##
## REQUIRES the Terrain3D addon to actually be installed first. This repo
## only ships pure GDScript, and Terrain3D is a compiled GDExtension that
## has to be downloaded for your platform — it can't be fetched or built
## from a cloud coding session, only through your own Godot editor:
##   1. In the Godot editor: AssetLib tab -> search "Terrain3D" -> Download
##      -> Install. (Or grab a release zip for your OS from
##      https://github.com/TokisanGames/Terrain3D/releases and extract its
##      `addons/terrain_3d` folder into this project's `addons/` folder.)
##   2. Project Settings / Plugins -> enable Terrain3D.
##   3. Restart the editor so it picks up this scene's Terrain3D node.
##   4. Open terrain3d_test.tscn, select the Terrain3D node (this script),
##      and confirm `Data Directory` in the Inspector points at
##      res://world/terrain3d_test_data (already set in the scene).
##   5. Click the "Generate Terraces" button this script adds to the
##      Inspector.
##
## How the terracing works: a noise field is sampled across one region and
## quantized to the nearest multiple of `step_height` — rounding height to
## a step — instead of being written straight through like normal rolling
## terrain. That produces flat plateaus with steep risers between them. A
## riser is still a 1-vertex-wide ramp (a heightmap can't make a
## mathematically perfect 90° wall), but at a few meters per step it reads
## as the chunky stacked-slab look from normal play distances.
##
## For perfectly crisp cube edges on top of this (closer to Deepwoken's most
## dramatic cliffs), the usual approach is a hybrid: this terrain for the
## broad landscape, plus hand-placed BoxMesh "cliff block" props at the
## terrace edges for the sharp vertical faces — the mesh_resize_gizmo addon
## (addons/mesh_resize_gizmo/) is good for blocking those out quickly.
##
## Texturing is NOT set up by this script — that needs real grass/dirt
## texture assets dragged into the Terrain3D Asset Dock in the editor first
## (see https://terrain3d.readthedocs.io/en/stable/docs/texture_painting.html).
## This script only enables the material's autoshader (slope-based texture
## blending) so that once you've added textures, flat tops and steep risers
## pick different ones automatically.

@export var step_height: float = 3.0    ## vertical distance between terraces
@export var max_height: float = 18.0    ## overall relief; terraces land every step_height up to this
@export var noise_scale: float = 0.015  ## lower = broader plateaus, higher = choppier
@export var noise_seed: int = 0

@export_tool_button("Generate Terraces") var generate_action = generate_terraces

func generate_terraces() -> void:
	if data == null:
		push_warning("Terrain3DTestGenerator: set this Terrain3D's Data Directory in the Inspector first.")
		return

	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_scale
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3

	var size: int = region_size   ## Terrain3D.region_size — a 256x256 heightmap image fills exactly one region
	var img := Image.create(size, size, false, Image.FORMAT_RF)
	for z in size:
		for x in size:
			var raw := (noise.get_noise_2d(x, z) + 1.0) * 0.5 * max_height   ## 0..max_height
			var terraced := roundf(raw / step_height) * step_height          ## snap to the nearest step — the actual "terracing"
			img.set_pixel(x, z, Color(terraced, 0.0, 0.0, 1.0))              ## FORMAT_RF reads height from the red channel

	data.import_images([img], global_position, 0.0, 1.0)

	if material != null:
		material.auto_shader_enabled = true

	print("Terrain3DTestGenerator: generated ~%d terrace steps across one %dx%d region." % [int(max_height / step_height), size, size])
