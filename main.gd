extends Node3D
## Composition root: builds the world, player, camera, UI and wires systems together.

## Set this in the Inspector (select "Main" in main.tscn) to point at a level
## you've built by hand in the editor instead of the code-built TestLevel
## blockout. Any scene works as long as its root contains: StaticBody3D world
## geometry on collision_layer 1 (bit 0), one or more Spawnpoint nodes, and
## any WorldEnemy nodes you want wandering the level — see world/hometown.tscn
## (the default, set below) or world/test_level.gd for worked examples of
## all three, and README.md for the full contract.
@export var level_scene: PackedScene = preload("res://world/hometown.tscn")

## Sun/sky/tonemap/glow/color-grading, all in one place — see
## world/environment_config.gd. Leave unset to use its defaults; duplicate
## that resource as a .tres and assign it here to try a different look
## without touching code.
@export var env_config: EnvironmentConfig

var player: Player
var cam: CameraRig
var encounters: EncounterManager

func _ready() -> void:
	Game.load_game()
	_build_environment()

	var level := level_scene.instantiate() if level_scene else TestLevel.new()
	add_child(level)

	player = Player.new()
	add_child(player)
	cam = CameraRig.new()
	add_child(cam)
	cam.target = player
	player.camera_rig = cam

	encounters = EncounterManager.new()
	add_child(encounters)
	encounters.setup(player, level)
	for e in get_tree().get_nodes_in_group(&"world_enemies"):
		encounters.register_world_enemy(e)

	var debug := DebugTools.new()
	add_child(debug)
	debug.setup(player, encounters)

	var ui := UiRoot.new()
	add_child(ui)
	ui.travel_menu.is_in_combat = func() -> bool: return encounters.busy

	Events.encounter_returned.connect(_on_encounter_returned)
	Events.fast_travel_requested.connect(_travel_to)
	_travel_to(Game.last_spawn if Game.last_spawn != &"" else &"start")

func _travel_to(id: StringName) -> void:
	for n in get_tree().get_nodes_in_group(&"spawnpoints"):
		var sp := n as Spawnpoint
		if sp.spawn_id == id:
			player.teleport(sp.respawn_position())
			cam.global_position = player.global_position
			return

func _on_encounter_returned(player_defeated: bool) -> void:
	if player_defeated:
		Game.stats.full_heal()
		_travel_to(Game.last_spawn if Game.last_spawn != &"" else &"start")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel_menu") and MenuBase.open_menu == null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _build_environment() -> void:
	var cfg := env_config if env_config else EnvironmentConfig.new()

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = cfg.sun_rotation_degrees
	sun.light_color = cfg.sun_color
	sun.light_energy = cfg.sun_energy
	sun.shadow_enabled = cfg.sun_shadows
	sun.shadow_blur = cfg.sun_shadow_blur
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = cfg.sky_top_color
	sky_mat.sky_horizon_color = cfg.sky_horizon_color
	sky_mat.ground_bottom_color = cfg.ground_bottom_color
	sky_mat.ground_horizon_color = cfg.ground_horizon_color
	env.sky.sky_material = sky_mat
	# A flat, near-neutral ambient color (not sourced from the sky) so a vivid
	# sky doesn't tint the character/props blue — only the sky itself is blue.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = cfg.ambient_color
	env.ambient_light_energy = cfg.ambient_energy

	env.tonemap_mode = cfg.tonemap_mode
	env.tonemap_exposure = cfg.exposure
	env.tonemap_white = cfg.white_point

	env.glow_enabled = cfg.glow_enabled
	env.glow_intensity = cfg.glow_intensity
	env.glow_bloom = cfg.glow_bloom
	env.glow_hdr_threshold = cfg.glow_hdr_threshold

	env.ssao_enabled = cfg.ssao_enabled
	env.ssao_intensity = cfg.ssao_intensity
	env.ssao_radius = cfg.ssao_radius

	env.adjustment_enabled = cfg.adjustment_enabled
	env.adjustment_brightness = cfg.brightness
	env.adjustment_contrast = cfg.contrast
	env.adjustment_saturation = cfg.saturation
	if cfg.color_correction_lut:
		env.adjustment_color_correction = cfg.color_correction_lut

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
