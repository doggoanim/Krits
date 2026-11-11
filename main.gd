extends Node3D
## Composition root: builds the world, player, camera, UI and wires systems together.

## Set this in the Inspector (select "Main" in main.tscn) to point at a level
## you've built by hand in the editor instead of the code-built TestLevel
## blockout. Any scene works as long as its root contains: StaticBody3D world
## geometry on collision_layer 1 (bit 0), one or more Spawnpoint nodes, and
## any WorldEnemy nodes you want wandering the level — see world/chesburg.tscn
## (the default, set below) or world/test_level.gd for worked examples of
## all three, and README.md for the full contract.
@export var level_scene: PackedScene = preload("res://world/chesburg.tscn")

## Sun/sky/tonemap/glow/color-grading, all in one place — see
## world/environment_config.gd. Leave unset to use its defaults; duplicate
## that resource as a .tres and assign it here to try a different look
## without touching code.
@export var env_config: EnvironmentConfig

## The same kind of resource, but for levels in the "interior_level" group
## (see world/interior_room.tscn's own root node) — see world/interior.tres
## for the current indoor look (warm sunset LUT, tighter contrast). Swapped
## in wholesale by _apply_level_lighting() whenever you step through a door,
## and swapped back out for env_config the moment you're outside again.
## Leave unset to just reuse env_config indoors too.
@export var interior_env_config: EnvironmentConfig = preload("res://world/interior.tres")

## Levels in the INTERIOR_GROUP additionally force the sky out for solid
## black and switch the sun off entirely — see _apply_level_lighting(). This
## part isn't a style choice interior_env_config can override: an enclosed
## room has no sky to show and no outdoor geometry on the far side of its
## walls to block the sun from shining straight through, so both would look
## broken regardless of which EnvironmentConfig is active.
const INTERIOR_GROUP := &"interior_level"
## Levels in this group are dungeons: dying inside respawns at the level's
## DoorSpawn marked `is_dungeon_start`, not at the last checkpoint outside.
const DUNGEON_GROUP := &"dungeon"
const DUNGEON_START_GROUP := &"dungeon_start"

## New-game intro (see _play_intro()).
const INTRO_FLAG := &"intro_seen"
const INTRO_BELL_WAIT := 2.0      ## black screen + first bell before the hero speaks
const INTRO_REVEAL_WAIT := 1.0    ## after the line closes, before the iris opens
const INTRO_LINE := "That bell calls for me, specifically, but at this hour?"

## Looping background music for every level OUTSIDE the INTERIOR_GROUP —
## right now that's always Chesburg, since it's the only outdoor level
## there is, but this is the one place to point at a different track later
## (or grow into a per-level mapping) without touching _apply_level_lighting()
## itself. Interiors are silent until they get a track of their own — see
## Music (core/music_player.gd) for the actual looping playback.
@export var outdoor_music: AudioStream = preload("res://sounds/Music/chesburg.ogg")

## Footstep sound sets, one per FootstepSurfaces.Surface (see
## core/footstep_surfaces.gd for how a surface is detected underfoot).
## Editable here, not in player_audio.gd, because Player/PlayerAudio are
## built entirely in code and never exist as their own node in a saved
## scene — this is the only Inspector they're ever reachable from.
## play_footstep() falls back to the grass set for any surface left empty.
@export var footstep_sfx_grass: Array[AudioStream] = PlayerAudio.DEFAULT_FOOTSTEP_SFX_GRASS
@export var footstep_sfx_dirt: Array[AudioStream] = PlayerAudio.DEFAULT_FOOTSTEP_SFX_DIRT
@export var footstep_sfx_rock: Array[AudioStream] = PlayerAudio.DEFAULT_FOOTSTEP_SFX_ROCK
@export var footstep_sfx_water: Array[AudioStream] = PlayerAudio.DEFAULT_FOOTSTEP_SFX_WATER
@export var footstep_sfx_wood: Array[AudioStream] = PlayerAudio.DEFAULT_FOOTSTEP_SFX_WOOD

## Low-HP warning vignette (see core/low_hp_vignette.gd) — hp/max_hp fraction
## below which the screen edges start darkening, and the color they darken
## toward.
@export var low_hp_vignette_threshold := 0.3
@export var low_hp_vignette_color := Color(0.5, 0.0, 0.0)

var player: Player
var _respawning := false
var _death_running := false
var _death_cam_hold: Node3D   ## parks the camera at the spot of death
var _death_overlay: DeathOverlay   ## draws the falling player over the iris's black
const DEATH_FREEZE_WAIT := 0.45   ## frozen on the pose before the iris starts
const DEATH_IRIS_RADIUS := 0.2    ## the gap left open around the player (screen heights)
const DEATH_IRIS_TIME := 0.7
const DEATH_PRE_HOP_WAIT := 0.4   ## beat in the iris before the hop
const DEATH_HOP_TIME := 1.4       ## up and down, until the player has dropped out of the gap
var _current_env_config: EnvironmentConfig   ## the look last applied, so Graphics options can re-apply it
var _bell: BellCall   ## the town bell calling the player to the mayor's house — see world/bell_call.gd
var _gold_lost := 0   ## filled in while the iris is closed, announced after it opens
var cam: CameraRig
var encounters: EncounterManager
var level: Node3D   ## the currently active level root — see _swap_level()

## See _build_environment()/_apply_environment_config()/_apply_level_lighting().
var _sun: DirectionalLight3D
var _env: Environment
var _reverb: LevelReverb

## Where a brand-new game starts: the player's own house (a level path, loaded
## lazily like a Door's target), arriving at its DoorSpawn `start_spawn_id`
## (the room's centre if it has none). Empty = start in `level_scene` as before.
@export_file("*.tscn") var start_level_path := "res://world/house_1_interior.tscn"
@export var start_spawn_id: StringName = &"enter"

func _ready() -> void:
	Game.load_game()
	_build_environment()
	_reverb = LevelReverb.new()
	add_child(_reverb)   # a level's LevelEnvironment can switch an echo on — see _apply_level_lighting()

	# A brand-new game (no spawnpoint reached yet) begins inside the player's own
	# house instead of out in the town.
	var starting_indoors := Game.last_spawn == &"" and not start_level_path.is_empty()
	var first_scene: PackedScene = load(start_level_path) if starting_indoors else level_scene
	level = first_scene.instantiate() if first_scene else TestLevel.new()
	add_child(level)
	_apply_level_lighting(level)
	_apply_level_music(level)

	_bell = BellCall.new()
	add_child(_bell)
	_bell.set_indoors(level.is_in_group(INTERIOR_GROUP))

	player = Player.new()
	add_child(player)
	player.audio.footstep_sfx_grass = footstep_sfx_grass
	player.audio.footstep_sfx_dirt = footstep_sfx_dirt
	player.audio.footstep_sfx_rock = footstep_sfx_rock
	player.audio.footstep_sfx_water = footstep_sfx_water
	player.audio.footstep_sfx_wood = footstep_sfx_wood
	cam = CameraRig.new()
	add_child(cam)
	cam.target = player
	player.camera_rig = cam

	# One shared outline pass for every character (see OutlineSystem) — has
	# to follow whichever camera is actually live, so it has to exist after
	# CameraRig does.
	var outlines := OutlineSystem.new()
	add_child(outlines)
	outlines.follow(cam.get_camera())

	# Painted look (see WatercolorEffect). The old retro PixelateEffect is
	# deliberately NOT added any more — it made the picture noisy; the class
	# is still in core/ if it's ever wanted back (add it right after this).
	add_child(WatercolorEffect.new())

	var low_hp_vignette := LowHpVignette.new()
	low_hp_vignette.low_hp_threshold = low_hp_vignette_threshold
	low_hp_vignette.vignette_color = low_hp_vignette_color
	add_child(low_hp_vignette)

	# Underwater screen tint + audio muffle — keyed off the CAMERA's own
	# position (see UnderwaterOverlay's header comment for why that's not the
	# same thing as the player's own submersion), so it needs the CameraRig
	# that already exists by this point.
	var underwater := UnderwaterOverlay.new()
	underwater.setup(cam)
	add_child(underwater)

	encounters = EncounterManager.new()
	add_child(encounters)
	encounters.setup(player, level)
	for e in get_tree().get_nodes_in_group(&"world_enemies"):
		encounters.register_world_enemy(e)

	add_child(CombatTutorial.new())   # the first-fight cards — see combat/combat_tutorial.gd

	var debug := DebugTools.new()
	add_child(debug)
	debug.setup(player, encounters)
	var render_debug := RenderDebug.new()   # Ctrl+Shift+1..0: flip effects off to hunt glitches
	add_child(render_debug)
	render_debug.setup(self, _env, _sun)

	var ui := UiRoot.new()
	add_child(ui)
	ui.travel_menu.is_in_combat = func() -> bool: return encounters.busy

	Events.encounter_returned.connect(_on_encounter_returned)
	Events.player_died.connect(_on_player_died)
	Events.fast_travel_requested.connect(_on_fast_travel_requested)
	Events.level_travel_requested.connect(_on_level_travel_requested)
	CombatWarmup.start(self, cam.get_camera())   # pre-draws the combat visuals so the first fight doesn't stall
	if starting_indoors:
		var start_pos: Variant = _find_spawn_in(level, start_spawn_id)
		player.teleport(start_pos if start_pos != null else level.global_position)
		cam.global_position = player.global_position
	else:
		_travel_to(Game.last_spawn if Game.last_spawn != &"" else &"start")
	if starting_indoors and not Game.flag(INTRO_FLAG):
		_play_intro()

## The very start of a new game: the screen stays black while the bell tolls
## (muffled, we are indoors), then the hero muses about it, and only then does
## the iris open on the room.
func _play_intro() -> void:
	Game.input_locked = true
	player.enter_cinematic()
	LoadingScreen.instance.hold()   # keeps the title->game reveal from opening yet
	_bell.start()
	await get_tree().create_timer(INTRO_BELL_WAIT).timeout
	DialogueBox.instance.start(DialogueNode.say(Game.player_name, INTRO_LINE))
	await Events.dialogue_ended
	player.enter_cinematic()   # the dialogue handed control back; keep them held for the reveal
	await get_tree().create_timer(INTRO_REVEAL_WAIT).timeout
	Game.set_flag(INTRO_FLAG)
	LoadingScreen.instance.release()
	await get_tree().create_timer(0.6).timeout
	player.teleport(player.global_position)   # back to Ground, in place
	Game.input_locked = false

func _travel_to(id: StringName) -> void:
	for n in get_tree().get_nodes_in_group(&"spawnpoints"):
		var sp := n as Spawnpoint
		if sp.spawn_id == id:
			player.teleport(sp.respawn_position())
			cam.global_position = player.global_position
			return

## Fast travel from the map menu: the same iris wipe as a door, with the
## teleport happening while it's fully closed.
func _on_fast_travel_requested(id: StringName) -> void:
	Game.input_locked = true
	player.enter_cinematic()
	await LoadingScreen.instance.run(func(): _travel_to(id))
	Game.input_locked = false

## A Door was used (see world/door.gd/Events.level_travel_requested). Freezes
## the player and locks input for the whole swap, then hands the actual work
## to LoadingScreen so it happens hidden behind the cover rather than visibly
## mid-frame — see _swap_level().
func _on_level_travel_requested(next_level: PackedScene, spawn_id: StringName) -> void:
	if next_level == null:
		return
	Game.input_locked = true
	player.enter_cinematic()
	await LoadingScreen.instance.run(func(): _swap_level(next_level, spawn_id))
	Game.input_locked = false

## Frees the current level, instantiates `next_level` in its place, and
## re-points everything that was keyed to the old level (encounters' world
## geometry, registered world enemies) at the new one before placing the
## player. Only ever called from inside LoadingScreen.run()'s covered window
## (see _on_level_travel_requested()) — nothing here is meant to be visible
## while it happens.
func _swap_level(next_level: PackedScene, spawn_id: StringName) -> void:
	if level:
		level.queue_free()   # deferred — see _find_spawn_in()'s doc comment for why that matters here
	level = next_level.instantiate()
	add_child(level)
	_apply_level_lighting(level)
	_apply_level_music(level)
	_bell.set_indoors(level.is_in_group(INTERIOR_GROUP))
	encounters.setup(player, level)
	for n in level.find_children("*", "", true, false):
		if n is WorldEnemy:
			encounters.register_world_enemy(n)
	var pos: Variant = _find_spawn_in(level, spawn_id)
	player.teleport(pos if pos != null else level.global_position)
	cam.global_position = player.global_position
	if Game.arrival_velocity != Vector3.ZERO:   # thrown out of the previous level (see EjectPit)
		player.velocity = Game.arrival_velocity
		Game.arrival_velocity = Vector3.ZERO
		player.machine.transition_to(&"Air")

## Scoped to `root` (the level that was just instantiated) rather than a
## global group lookup like _travel_to() above uses — right after a swap the
## OLD level's nodes are technically still in the tree (queue_free() only
## takes effect at end of frame) and could carry the exact same spawn id
## (every interior's own DoorSpawn defaults to &"enter", for instance), so a
## global search could still match the one about to disappear instead of the
## new level's own. Scoping the search to `root` sidesteps that entirely.
func _find_spawn_in(root: Node, id: StringName) -> Variant:
	for n in root.find_children("*", "", true, false):
		if n is Spawnpoint and (n as Spawnpoint).spawn_id == id:
			return (n as Spawnpoint).respawn_position()
		if n is DoorSpawn and (n as DoorSpawn).spawn_id == id:
			return (n as DoorSpawn).respawn_position()
	return null

func _on_encounter_returned(player_defeated: bool) -> void:
	if player_defeated:
		_respawn_after_death()

## The player died (see Player._begin_death()): the music muffles right away.
## If it happened in a fight, EncounterManager calls _respawn_after_death()
## once the arena has wrapped up; anywhere else we do it ourselves.
func _on_player_died() -> void:
	Music.force_muffle = true
	_death_running = true
	await _play_death_sequence()
	_death_running = false
	if player.dead and not encounters.busy:
		_respawn_after_death()

## Super Mario death: a beat frozen on the pose, the iris closes in on the
## player but stops short leaving a gap, the player hops up and drops out, and
## only then does the iris finish shutting (that part is _respawn_after_death()).
## All in real time — the hit-stop freeze would otherwise stretch the waits.
func _play_death_sequence() -> void:
	_death_cam_hold = Node3D.new()   # the camera stays where it was while the player falls away
	add_child(_death_cam_hold)
	_death_cam_hold.global_position = player.global_position
	cam.target = _death_cam_hold
	await get_tree().create_timer(DEATH_FREEZE_WAIT, true, false, true).timeout
	var cam3d := cam.get_camera()
	var uv := cam3d.unproject_position(player.global_position + Vector3.UP * 0.9) / get_viewport().get_visible_rect().size
	await LoadingScreen.instance.close_to(DEATH_IRIS_RADIUS, uv, DEATH_IRIS_TIME)
	await get_tree().create_timer(DEATH_PRE_HOP_WAIT, true, false, true).timeout
	if _death_overlay == null:
		_death_overlay = DeathOverlay.new()
		add_child(_death_overlay)
	_death_overlay.show_player(player, cam3d)   # the fall stays visible over the black
	player.death_hop()
	await get_tree().create_timer(DEATH_HOP_TIME, true, false, true).timeout

## Iris wipe, then — while the screen is fully covered — lose some gold, heal
## and put the player back at the last spawnpoint.
func _respawn_after_death() -> void:
	if _respawning:
		return
	_respawning = true
	Game.input_locked = true
	while _death_running:   # a fight's teardown can finish before the death sequence does
		await get_tree().process_frame
	await LoadingScreen.instance.run(func():
		if _death_overlay != null:
			_death_overlay.clear()   # fully covered now: the player goes back to being drawn normally
		cam.target = player   # the camera was parked while the player fell away (see _play_death_sequence())
		if is_instance_valid(_death_cam_hold):
			_death_cam_hold.queue_free()
		_gold_lost = Game.stats.lose_gold(PlayerStats.DEATH_GOLD_LOSS)
		Game.stats.full_heal()
		if not _respawn_in_dungeon():
			_travel_to(Game.last_spawn if Game.last_spawn != &"" else &"start")
		Music.force_muffle = false)
	Game.input_locked = false
	_respawning = false
	if _gold_lost > 0:
		Events.notice.emit("Dropped %d gold." % _gold_lost)

## Inside a dungeon, death sends the player back to the dungeon's own start.
## Returns false when the current level isn't a dungeon (or has no marked start).
func _respawn_in_dungeon() -> bool:
	if level == null or not level.is_in_group(DUNGEON_GROUP):
		return false
	for n in get_tree().get_nodes_in_group(DUNGEON_START_GROUP):
		if level.is_ancestor_of(n):
			player.teleport((n as DoorSpawn).respawn_position())
			cam.global_position = player.global_position
			return true
	return false

## Builds the one Sun/WorldEnvironment pair the whole game uses, as direct
## children of Main rather than part of the swappable `level` (see `level`'s
## own doc comment) so they persist untouched across every _swap_level() —
## only their properties change, via _apply_environment_config(). Starts out
## wearing env_config's outdoor look; _apply_level_lighting() takes it from
## here the moment a level is actually in hand.
func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	add_child(sun)

	var env := Environment.new()
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	# A flat, near-neutral ambient color (not sourced from the sky) so a vivid
	# sky doesn't tint the character/props blue — only the sky itself is blue.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_sun = sun
	_sun.add_to_group(&"sun")   # CharacterFillLight places itself opposite this
	_env = env
	_apply_environment_config(env_config if env_config else EnvironmentConfig.new())
	Settings.changed.connect(_on_setting_changed)

func _on_setting_changed(key: StringName) -> void:
	if String(key).begins_with("graphics/") and _current_env_config != null:
		_apply_environment_config(_current_env_config)

## Applies every look/grading value an EnvironmentConfig carries — sun,
## sky colors, ambient, tonemap, glow, SSAO, volumetric fog, color grading —
## onto the shared Sun/Environment _build_environment() built once. Used for
## env_config at startup, and again by _apply_level_lighting() with whichever
## config fits every time a level loads, so swapping between outdoor and an
## interior_level re-grades the whole scene, not just its background.
##
## Deliberately leaves background_mode/background_color and the sun's own
## `visible` alone — those are the structural indoor/outdoor split
## _apply_level_lighting() layers on top afterward, not a style choice this
## config gets a say in (see INTERIOR_GROUP's doc comment).
func _apply_environment_config(cfg: EnvironmentConfig) -> void:
	_current_env_config = cfg   # re-applied when a Graphics option changes, see _on_setting_changed()
	_sun.rotation_degrees = cfg.sun_rotation_degrees
	_sun.light_color = cfg.sun_color
	_sun.light_energy = cfg.sun_energy
	_sun.shadow_enabled = cfg.sun_shadows and Settings.get_value(&"graphics/shadows")
	_sun.shadow_blur = cfg.sun_shadow_blur
	# Shadow map only covers what's near the player: the same texture budget over
	# a shorter range = much sharper, less jagged edges (and cheaper to render).
	_sun.directional_shadow_max_distance = 50.0
	# Blocky, camera-dependent shadows come from the cascades: each one is a
	# separate shadow map and their edges show as blocks that shift as the camera
	# turns. Blending the cascades hides the seams; the bias keeps surfaces from
	# self-shadowing in stripes at the finer resolution.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_split_1 = 0.08
	_sun.directional_shadow_split_2 = 0.2
	_sun.directional_shadow_split_3 = 0.45
	_sun.shadow_normal_bias = 1.5
	_sun.light_volumetric_fog_energy = cfg.sun_volumetric_fog_energy

	_apply_sky(cfg)
	RenderingServer.global_shader_parameter_set(&"level_tint", cfg.character_tint)
	RenderingServer.global_shader_parameter_set(&"level_tint_amount", cfg.character_tint_amount)

	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_color = cfg.ambient_color
	_env.ambient_light_energy = cfg.ambient_energy

	_env.tonemap_mode = cfg.tonemap_mode
	_env.tonemap_exposure = cfg.exposure
	_env.tonemap_white = cfg.white_point

	_env.glow_enabled = cfg.glow_enabled
	_env.glow_intensity = cfg.glow_intensity
	_env.glow_bloom = cfg.glow_bloom
	_env.glow_hdr_threshold = cfg.glow_hdr_threshold

	_env.ssao_enabled = cfg.ssao_enabled and Settings.get_value(&"graphics/ssao")
	_env.ssao_intensity = cfg.ssao_intensity
	_env.ssao_radius = cfg.ssao_radius

	# Distance haze (cheap depth fog) — see EnvironmentConfig's Distance Haze group.
	_env.fog_enabled = cfg.haze_enabled
	_env.fog_light_color = cfg.haze_color
	_env.fog_density = cfg.haze_density
	_env.fog_aerial_perspective = cfg.haze_aerial_perspective
	_env.fog_sky_affect = 0.0   # keep the sky's own colors, haze only affects geometry

	# Volumetric fog is what actually produces visible sun shafts/god rays
	# through trees and gaps (see EnvironmentConfig's header comment on the
	# group) — it's the sun's light_volumetric_fog_energy above, set on the
	# DirectionalLight itself, that makes this fog volume actually light up
	# instead of just sitting there as flat haze.
	_env.volumetric_fog_enabled = cfg.volumetric_fog_enabled and Settings.get_value(&"graphics/volumetric_fog")
	# The fog volume is a coarse 3D grid; drawn over the sky it shows up as big
	# blocky patches in the clouds. Keep it on geometry only.
	_env.volumetric_fog_sky_affect = 0.0
	_env.volumetric_fog_density = cfg.volumetric_fog_density
	_env.volumetric_fog_albedo = cfg.volumetric_fog_albedo
	_env.volumetric_fog_anisotropy = cfg.volumetric_fog_anisotropy
	_env.volumetric_fog_length = cfg.volumetric_fog_length
	_env.volumetric_fog_gi_inject = cfg.volumetric_fog_gi_inject

	_env.adjustment_enabled = cfg.adjustment_enabled
	_env.adjustment_brightness = cfg.brightness
	_env.adjustment_contrast = cfg.contrast
	_env.adjustment_saturation = cfg.saturation
	# Set unconditionally (not just "if present") so going back to a config
	# with no LUT of its own actually clears one a previous config set.
	_env.adjustment_color_correction = cfg.color_correction_lut

## Sky material: the config's custom sky shader if it has one, otherwise the
## plain procedural gradient. The material object is swapped only when the
## kind changes (not every level load).
func _apply_sky(cfg: EnvironmentConfig) -> void:
	if cfg.sky_shader:
		var mat := _env.sky.sky_material as ShaderMaterial
		if mat == null:
			mat = ShaderMaterial.new()
			_env.sky.sky_material = mat
		mat.shader = cfg.sky_shader
		for uniform_name: StringName in cfg.sky_shader_params:
			mat.set_shader_parameter(uniform_name, cfg.sky_shader_params[uniform_name])
		return
	var sky_mat := _env.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		sky_mat = ProceduralSkyMaterial.new()
		_env.sky.sky_material = sky_mat
	sky_mat.sky_top_color = cfg.sky_top_color
	sky_mat.sky_horizon_color = cfg.sky_horizon_color
	sky_mat.ground_bottom_color = cfg.ground_bottom_color
	sky_mat.ground_horizon_color = cfg.ground_horizon_color

## Re-grades the whole scene for whichever side of a door you're now on, and
## additionally force the sky/sun off for a plain black void whenever the
## just-loaded level is in the INTERIOR_GROUP — called right after
## instancing a level, both on first load and on every Door swap. See
## interior_env_config's doc comment for the look itself, and
## INTERIOR_GROUP's for why the void/sun part isn't part of that config.
func _apply_level_lighting(lvl: Node) -> void:
	var indoor := lvl.is_in_group(INTERIOR_GROUP)
	var cfg := interior_env_config if indoor and interior_env_config else env_config
	# A level's own LevelEnvironment node (its own color grade, reverb) beats both.
	var level_env: LevelEnvironment = null
	for child in lvl.get_children():
		if child is LevelEnvironment:
			level_env = child as LevelEnvironment
			break
	if level_env != null and level_env.config != null:
		cfg = level_env.config
	_reverb.apply(level_env)
	var applied := cfg if cfg else EnvironmentConfig.new()
	_apply_environment_config(applied)
	HipLantern.level_boost = applied.lantern_boost
	if applied.toon_world:
		WorldToon.apply(lvl)
	if indoor:
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = Color.BLACK
	_sun.visible = not indoor

## Starts/stops outdoor_music to match indoor/outdoor, same INTERIOR_GROUP
## check _apply_level_lighting() uses — called right alongside it, wherever
## a level is instanced. Music.play() is already a no-op if that track is
## already playing, so this is safe to call on every level load without
## restarting the song.
func _apply_level_music(lvl: Node) -> void:
	if lvl.is_in_group(INTERIOR_GROUP):
		Music.stop()
	else:
		Music.play(outdoor_music)
