class_name FishingSession
extends Node3D
## One cast, start to finish. Started by the Fishing ability (AbilityRunner):
##   WAIT  the bobber floats; a fish bites after a random while (cancel with Crouch)
##   BITE  "!" — press Jump within BITE_WINDOW or it gets away
##   REEL  a small tug-of-war: hold Jump to slide the catch zone right, let go and
##         it drifts left; keep the zone on the fish to fill the bar
## The rod (FishingRod) is in the player's hand and the player's fishing clips
## play: fishing_waiting while waiting/biting, fishing_reeling while reeling,
## then fishing_reeled_successful / _failed / _empty as the cast ends.
## The player is held still (Frozen) for the whole thing and released at the end,
## including when the level is swapped out from under the session.

enum Phase { WAIT, BITE, REEL, CELEBRATE, DONE }

const GROUP := &"fishing_session"
const CAST_NEAREST := 2.5          ## the line lands on the closest water between these distances in front of the player...
const CAST_FARTHEST := 8.0
const CAST_STEP := 0.5             ## ...checked at this spacing
const MAX_SURFACE_DROP := 6.0      ## the water may be at most this far above/below the player's feet
const COVER_CHECK_HEIGHT := 6.0     ## how far above the surface to look for terrain covering the water
const CAST_TIME := 0.35            ## the bobber's flight from the rod to the water
const CAST_ARC := 1.6              ## how high it arcs
const CATCH_ARC := 2.4             ## how high the landed fish leaps
const OUTRO_LENGTH := {          ## seconds each finishing clip plays before the player is released
	PlayerVisual.ANIM_FISH_SUCCESS: 1.0,
	PlayerVisual.ANIM_FISH_FAIL: 1.25,
	PlayerVisual.ANIM_FISH_EMPTY: 0.75,
}
const CATCH_TIME := 0.7
const CATCH_MAX_LENGTH := 3.0     ## the leaping fish is drawn at most this long, however huge the catch
const RIPPLE_COLOR := Color(1.0, 1.0, 1.0, 0.7)
const RUMBLE_INTERVAL := 0.16      ## while the zone is on the fish: a small camera tremble this often
const WAIT_TIME := Vector2(2.0, 5.5)
const BITE_WINDOW := 0.9
const HAND_HEIGHT := 1.3
const PROGRESS_START := 0.3
const PROGRESS_GAIN := 0.3         ## per second while the zone covers the fish
const PROGRESS_LOSS := 0.2         ## per second while it doesn't
const HOOK_ACCEL := 3.2
const HOOK_MAX_SPEED := 0.9
const BAR_SIZE := Vector2(560.0, 116.0)   ## the meter's footprint (see FishingMeter.PANEL_SIZE)

var _player: Player
var _water: WaterVolume
var _spot := Vector3.ZERO
var _phase := Phase.WAIT
var _timer := 0.0
const CAST_INPUT_DELAY := 0.7   ## seconds after casting before a press can pull the line in
var _age := 0.0
var _catch: Dictionary = {}
var _size := 1.0              ## how big this particular fish is (FishCatalog.roll_size())
var _froze := false
var _click_pressed := false
var _click_was_down := true   ## true at the start so the click that cast the line can't also hook it
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh := ImmediateMesh.new()

# reel-in minigame state (0..1 along the bar)
var _fish_pos := 0.5
var _fish_target := 0.5
var _retarget := 0.0
var _hook_pos := 0.5
var _hook_vel := 0.0
var _progress := PROGRESS_START
var _ui: CanvasLayer
var _meter: FishingMeter
var _plate_tween: Tween
var _cast_t := 0.0
var _rumble_t := 0.0
var _tension := 0.0           ## 0..1: how hard the line is pulled (0 slack/sagging, 1 taut)
var _plate: KeyHintPlate
var _rod: FishingRod
var _sfx := FishingSfx.new()

## Jump or the left mouse button: hooks the fish at the bite and reels after.
func _hook_pressed() -> bool:
	return Input.is_action_just_pressed(&"jump") or _click_pressed

func _hook_held() -> bool:
	return Input.is_action_pressed(&"jump") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

## Left-click "just pressed" for this frame, tracked by hand (there's no action for it).
func _poll_click() -> void:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_click_pressed = down and not _click_was_down
	_click_was_down = down

## Starts a cast in front of the player. Returns "" on success, else why not.
static func start(player: Player, tree: SceneTree) -> String:
	if tree.get_first_node_in_group(GROUP) != null:
		return ""
	if Game.in_combat or player.machine.current_name != &"Ground":
		return "Can't fish right now."
	var found := _find_water(player)
	if found.is_empty():
		return "No water to fish in."
	var session := FishingSession.new()
	player.get_parent().add_child(session)
	session._begin(player, found["water"], found["spot"])
	return ""

## The nearest water in front of the player, any body of water: it only has to
## be a WaterVolume whose footprint is there and whose surface is near the
## player's own height (so a lake far below a cliff doesn't count).
static func _find_water(player: Player) -> Dictionary:
	var dist := CAST_NEAREST
	while dist <= CAST_FARTHEST:
		var p := player.global_position + player.facing * dist
		for w in WaterVolume.active:
			if w.covers_xz(p) and absf(w.surface_world_y() - player.global_position.y) <= MAX_SURFACE_DROP:
				var spot := Vector3(p.x, w.surface_world_y(), p.z)
				if _is_open_water(player, spot):
					return {"water": w, "spot": spot}
		dist += CAST_STEP
	return {}

## Water volumes can run through terrain, so a spot inside one isn't always
## visible water. It is only fishable if nothing solid covers it from above and
## nothing solid is in the way of the line from the player's hand.
static func _is_open_water(player: Player, spot: Vector3) -> bool:
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var cover := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * COVER_CHECK_HEIGHT, spot + Vector3.UP * 0.05, 1)
	cover.exclude = exclude
	if not space.intersect_ray(cover).is_empty():
		return false   # terrain sits over this part of the water
	var hand := player.global_position + Vector3.UP * HAND_HEIGHT
	var sight := PhysicsRayQueryParameters3D.create(hand, spot + Vector3.UP * 0.1, 1)
	sight.exclude = exclude
	return space.intersect_ray(sight).is_empty()

func _begin(player: Player, water: WaterVolume, spot: Vector3) -> void:
	add_to_group(GROUP)
	_player = player
	_water = water
	_spot = spot
	_catch = FishCatalog.roll()
	_size = FishCatalog.roll_size()
	_timer = randf_range(WAIT_TIME.x, WAIT_TIME.y)
	player.enter_cinematic()
	_froze = true
	var toward := spot - player.global_position
	toward.y = 0.0
	player.face(toward)
	Events.player_hurt.connect(_on_player_hurt)
	_rod = FishingRod.equip(player)
	_pose(PlayerVisual.ANIM_FISH_WAIT)
	_build_visuals()
	_sfx.world = get_parent()
	add_child(_sfx)
	_sfx.cast(player.global_position)
	_player.visual.squash_stretch(0.85, 1.12)   # the wind-up of the cast

func _exit_tree() -> void:
	_release()

# ---------------------------------------------------------------- flow

func _process(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	if not is_instance_valid(_player) or _player.dead:
		_finish()
		return
	_age += delta
	_poll_click()
	_advance_cast(delta)
	_update_visuals()
	if _phase == Phase.CELEBRATE:
		return
	if Input.is_action_just_pressed(&"crouch_pound"):
		_end("You reel the line in.", PlayerVisual.ANIM_FISH_EMPTY)
		return
	match _phase:
		Phase.WAIT: _wait(delta)
		Phase.BITE: _bite(delta)
		Phase.REEL: _reel(delta)

func _wait(delta: float) -> void:
	_timer -= delta
	# Right after casting, a stray press (still mashing the cast key, a double click)
	# must not yank the line straight back in.
	if _age > CAST_INPUT_DELAY and _hook_pressed():
		_end("Pulled in too early.", PlayerVisual.ANIM_FISH_EMPTY)
	elif _timer <= 0.0:
		_phase = Phase.BITE
		_timer = BITE_WINDOW
		Telegraph.exclaim(_bobber, 0.7)
		_build_ui()   # the key plate appears with the bite
		_sfx.hooked(_spot)
		_player.effects.burst_water_splash(_spot, true, false)
		_player.audio.play_water_splash(false)
		_ripple(_spot, 2.6)
		_shake(0.25)
		_player.visual.squash_stretch(1.1, 0.92)

func _bite(delta: float) -> void:
	_timer -= delta
	if _hook_pressed():
		_start_reel()
	elif _timer <= 0.0:
		_end("It got away.", PlayerVisual.ANIM_FISH_EMPTY)

func _start_reel() -> void:
	_phase = Phase.REEL
	_pose(PlayerVisual.ANIM_FISH_REEL)
	_build_bar()
	_sfx.start_reel_loop()
	HitStop.freeze(0.07)   # the yank of setting the hook
	_shake(0.4)
	_player.effects.burst_water_splash(_spot, true, true)
	_ripple(_spot, 3.2)
	_player.visual.squash_stretch(0.8, 1.15)
	_fish_pos = 0.5
	_fish_target = 0.5
	_hook_pos = 0.5
	_hook_vel = 0.0
	_progress = PROGRESS_START
	_retarget = 0.0

func _reel(delta: float) -> void:
	# The fish darts toward a random target, picking a new one every so often.
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = randf_range(0.5, 1.2)
		_fish_target = randf()
	_fish_pos = move_toward(_fish_pos, _fish_target, float(_catch["speed"]) * delta)
	# Holding Jump slides the catch zone right; letting go lets it fall back left.
	var held := _hook_held()
	_hook_vel = clampf(_hook_vel + (HOOK_ACCEL if held else -HOOK_ACCEL) * delta, -HOOK_MAX_SPEED, HOOK_MAX_SPEED)
	_hook_pos += _hook_vel * delta
	# The zone is drawn inside the track, so its CENTRE can only travel between
	# half a zone-width from each end — clamping to 0..1 instead left it
	# "moving" while already drawn against the wall, so it felt stuck there.
	var half := float(_catch["zone"]) * 0.5
	var lo := half
	var hi := 1.0 - half
	if _hook_pos <= lo or _hook_pos >= hi:
		_hook_pos = clampf(_hook_pos, lo, hi)
		_hook_vel = 0.0
	var covered := absf(_fish_pos - _hook_pos) <= half
	_progress += (PROGRESS_GAIN if covered else -PROGRESS_LOSS) * delta
	_update_ui(half, covered)
	_tension = move_toward(_tension, 1.0 if covered else 0.2, delta * 4.0)
	_sfx.set_reel_intensity(_tension)
	_reel_juice(delta, covered)
	if _progress >= 1.0:
		_land_catch()
	elif _progress <= 0.0:
		_end("The fish slipped the hook.", PlayerVisual.ANIM_FISH_FAIL)

## Reeling feedback: the meter trembles while you're on the fish, flushes red
## when you're about to lose it, the camera rumbles, and the water thrashes.
func _reel_juice(delta: float, covered: bool) -> void:
	if _meter != null:
		var base := Vector2((BAR_SIZE.x - FishingMeter.PANEL_SIZE.x) * 0.5, 0.0)
		var jitter := (2.5 if covered else 0.0) * Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		_meter.position = base + jitter
		var danger := clampf(1.0 - _progress / 0.3, 0.0, 1.0) if not covered else 0.0
		_meter.modulate = Color(1.0, 1.0 - 0.3 * danger, 1.0 - 0.4 * danger, _meter.modulate.a)
	_rumble_t -= delta
	if covered and _rumble_t <= 0.0:
		_rumble_t = RUMBLE_INTERVAL
		_shake(0.07)
		if randf() < 0.5:
			_player.effects.burst_water_splash(_spot + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)), true, false)

func _land_catch() -> void:
	var id: StringName = _catch["id"]
	var item := ItemLibrary.by_id(id)
	if not Game.inventory.can_fit(id, 1):
		_end("Your bag is full: the fish swims off.", PlayerVisual.ANIM_FISH_FAIL)
		return
	_celebrate(id, item)

## The payoff: freeze-frame, a big splash, the fish leaps out of the water in an
## arc to over the player's head (a coloured stand-in in the item's colour),
## the meter pops away, then the item is handed over.
func _celebrate(id: StringName, item: ItemData) -> void:
	_phase = Phase.CELEBRATE
	_pose(PlayerVisual.ANIM_FISH_SUCCESS)
	_sfx.stop_reel_loop()
	HitStop.freeze(0.1)
	_shake(0.5)
	_player.audio.play_water_splash(true)
	_player.effects.burst_water_splash(_spot, true, true)
	_ripple(_spot, 4.0)
	if is_instance_valid(_plate):
		_plate.visible = false
	_bobber.visible = false   # the fish (and the line with it) leave the water
	_line.visible = false
	if _meter != null:
		_meter.pivot_offset = FishingMeter.PANEL_SIZE * 0.5
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(_meter, "scale", Vector2(1.25, 1.25), 0.25)
		tw.tween_property(_meter, "modulate:a", 0.0, 0.25)
	var fish_color := item.color if item != null else Color(0.8, 0.85, 0.9)
	var fish := FishModel.build(fish_color)
	var fish_length := minf(FishCatalog.length_of(id, _size), CATCH_MAX_LENGTH)   # a colossal one still fits the screen
	add_child(fish)
	var start := _spot
	var end := _player.global_position + Vector3.UP * (Player.STAND_HEIGHT + 0.6)
	var arc := func(t: float) -> void:
		if not is_instance_valid(fish):
			return
		fish.global_position = start.lerp(end, t) + Vector3.UP * sin(t * PI) * CATCH_ARC
		fish.rotation = Vector3(t * TAU * 2.0, 0.0, t * TAU)   # flips as it flies
		var pop := 1.0 + 0.5 * sin(t * PI)
		fish.scale = Vector3.ONE * pop * fish_length
	var flight := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight.tween_method(arc, 0.0, 1.0, CATCH_TIME)
	await flight.finished
	if not is_instance_valid(self) or _phase == Phase.DONE:
		return
	VFX.shatter(self, end, fish_color, 0.8)   # a burst of sparkle where it's caught
	fish.queue_free()
	_shake(0.3)
	_player.visual.squash_stretch(1.2, 0.88)
	ItemGet.give(id, 1, Callable(), _size)
	var size_word := FishCatalog.size_word(_size)
	var title := ("%s %s" % [size_word, item.display_name] if size_word != "" else item.display_name) if item else String(id)
	# name (with its size word), then its rarity and length under it
	_end("Caught: %s!\n%s · %s" % [title, FishCatalog.rarity_text(id), FishCatalog.length_text(id, _size)], &"", OUTRO_LENGTH[PlayerVisual.ANIM_FISH_SUCCESS] - CATCH_TIME)   # let the landing clip finish

func _on_player_hurt(_from: Vector3) -> void:
	_end("")

## Ends the cast with a message (empty = none). `outro`: a finishing clip to
## play first (the player stays put for its length); `extra_wait`: a further
## pause before the player is released (the landing clip is already playing).
func _end(message: String, outro := &"", extra_wait := 0.0) -> void:
	if _phase != Phase.CELEBRATE and _phase != Phase.DONE and message != "":
		_sfx.reel_in(_spot)   # the line comes back in empty
	if message != "":
		Events.notice.emit(message)
	var wait := extra_wait
	if outro != &"" and is_instance_valid(_player) and not _player.dead and _phase != Phase.DONE:
		_phase = Phase.CELEBRATE   # no more input or minigame while it plays
		_sfx.stop_reel_loop()
		_bobber.visible = false
		_line.visible = false
		if is_instance_valid(_plate):
			_plate.visible = false
		if is_instance_valid(_meter):
			_meter.visible = false
		_pose(outro, float(OUTRO_LENGTH.get(outro, 1.0)))
		wait = float(OUTRO_LENGTH.get(outro, 1.0))
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
		if not is_instance_valid(self) or _phase == Phase.DONE:
			return
	_finish()

## Plays one of the fishing clips on the player and keeps it there (`duration`
## seconds; the default holds until the cast ends).
func _pose(anim: StringName, duration := 600.0) -> void:
	if is_instance_valid(_player):
		_player.visual.play_hold(anim, duration, 1.0, true, 0.12)

func _finish() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	_sfx.stop_reel_loop()
	_release()
	queue_free()

func _release() -> void:
	if Events.player_hurt.is_connected(_on_player_hurt):
		Events.player_hurt.disconnect(_on_player_hurt)
	if _rod != null:
		_rod.release()
		_rod = null
	if _froze and is_instance_valid(_player):
		_player.visual.cancel_hold()   # back to the normal idle/run clips
	if _froze and is_instance_valid(_player) and _player.machine.current_name == &"Frozen":
		_player.machine.transition_to(&"Ground")
	_froze = false
	if is_instance_valid(_ui):
		_ui.queue_free()

# ---------------------------------------------------------------- 3D bits

func _build_visuals() -> void:
	_bobber = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.13
	ball.height = 0.26
	_bobber.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.25, 0.2)
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_bobber.material_override = mat
	add_child(_bobber)
	_bobber.global_position = _spot
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line.material_override = line_mat
	add_child(_line)
	_line.global_transform = Transform3D.IDENTITY

## Intentionally a no-op: fishing has no camera shake.
func _shake(_amount: float) -> void:
	pass   # fishing doesn't shake the camera; kept as one switch so the call sites stay readable

## Flies the bobber from the rod to the water at the start; when it lands:
## splash, ripple, a little kick.
func _advance_cast(delta: float) -> void:
	if _cast_t >= 1.0:
		return
	_cast_t = minf(1.0, _cast_t + delta / CAST_TIME)
	if _cast_t >= 1.0:
		_sfx.bait_lands(_spot)
		_player.effects.burst_water_splash(_spot, true, false)
		_player.audio.play_water_splash(false)
		_ripple(_spot, 2.2)
		_shake(0.12)

## An expanding, fading ring on the water surface.
func _ripple(at: Vector3, final_scale: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.5
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = RIPPLE_COLOR
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(0.3, 0.05, 0.3)
	add_child(ring)
	ring.global_position = at + Vector3.UP * 0.03
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3(final_scale, 0.05, final_scale), 0.7)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(ring.queue_free)

func _update_visuals() -> void:
	var bob := sin(_age * 3.0) * 0.03
	if _phase == Phase.BITE:
		bob = -0.12 + sin(_age * 30.0) * 0.04   # tugged under
	elif _phase == Phase.REEL:
		bob = sin(_age * 14.0) * 0.06
	var hand := _player.global_position + Vector3.UP * HAND_HEIGHT + _player.facing * 0.4
	if _rod != null:
		hand = _rod.tip_position()   # the line leaves the rod's tip
	if _cast_t < 1.0:   # still in flight: an arc from the rod to the spot
		_bobber.global_position = hand.lerp(_spot, _cast_t) + Vector3.UP * sin(_cast_t * PI) * CAST_ARC
	else:
		_bobber.global_position = _spot + Vector3.UP * (0.05 + bob)
	var tip := _bobber.global_position
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 9:   # a gentle sag so it reads as a line, not a rod
		var t := float(i) / 8.0
		var p := hand.lerp(tip, t) + Vector3.DOWN * (sin(t * PI) * 0.35 * (1.0 - _tension * 0.9))
		_line_mesh.surface_add_vertex(p)
	_line_mesh.surface_end()

# ---------------------------------------------------------------- reel-in UI

const PLATE_SCENE := preload("res://ui/widgets/key_hint_plate.tscn")

var _box: Control

## The key prompt: just the hand-drawn key plate (see KeyHintPlate) showing the
## key that hooks and reels. Appears when the fish bites and stays for the reel.
func _build_ui() -> void:
	if _ui != null:
		return
	_ui = CanvasLayer.new()
	_ui.layer = 15
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	_box = Control.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.position = Vector2(-BAR_SIZE.x * 0.5, -250.0)
	_box.size = BAR_SIZE
	root.add_child(_box)
	var plate := PLATE_SCENE.instantiate() as KeyHintPlate
	_plate = plate
	_box.add_child(plate)
	plate.set_key(InputSetup.key_label(Settings.get_binding(&"jump")))
	plate.position = Vector2((BAR_SIZE.x - plate.custom_minimum_size.x) * 0.5, -plate.custom_minimum_size.y - 12.0)
	# Pops in with the bite, then throbs until you hook it.
	plate.pivot_offset = plate.custom_minimum_size * 0.5
	plate.scale = Vector2(1.5, 1.5)
	_plate_tween = create_tween()
	_plate_tween.tween_property(plate, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.set_loops()
	_plate_tween.tween_property(plate, "scale", Vector2(1.12, 1.12), 0.22)
	_plate_tween.tween_property(plate, "scale", Vector2.ONE, 0.22)

## The reel-in meter (see FishingMeter), under the key plate.
func _build_bar() -> void:
	_build_ui()
	if _plate_tween != null:
		_plate_tween.kill()   # stop the "press now" throb once you've hooked it
		_plate_tween = null
		_plate.scale = Vector2.ONE
	_meter = FishingMeter.new()
	_meter.position = Vector2((BAR_SIZE.x - FishingMeter.PANEL_SIZE.x) * 0.5, 0.0)
	_box.add_child(_meter)
	_meter.pivot_offset = FishingMeter.PANEL_SIZE * 0.5
	_meter.scale = Vector2(0.6, 0.6)
	_meter.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_meter, "scale", Vector2.ONE, 0.25)
	tw.tween_property(_meter, "modulate:a", 1.0, 0.15)

func _update_ui(half: float, covered: bool) -> void:
	if _meter == null:
		return
	_meter.fish_pos = _fish_pos
	_meter.zone_pos = _hook_pos
	_meter.zone_width = half * 2.0
	_meter.progress = _progress
	_meter.covered = covered
