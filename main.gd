extends Node3D
## Composition root: builds the world, player, camera, UI and wires systems together.

var player: Player
var cam: CameraRig
var encounters: EncounterManager
var _env: Environment

func _ready() -> void:
	Game.load_game()
	_build_environment()

	var level := TestLevel.new()
	add_child(level)

	player = Player.new()
	add_child(player)
	cam = CameraRig.new()
	add_child(cam)
	cam.target = player
	player.camera_rig = cam

	encounters = EncounterManager.new()
	add_child(encounters)
	encounters.setup(player, level, _env)
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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	_env = Environment.new()
	var env := _env
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
