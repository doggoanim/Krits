class_name FishingSfx
extends Node
## All of fishing's sound, so FishingSession only says WHAT happened ("the bait
## landed", "it bit") and never touches audio nodes. One-shots are parented to
## `world` (the level), not to the session, so they finish even though the
## session frees itself the moment a cast ends.

const SFX_DIR := "res://sounds/SFX/"
const CAST: AudioStream = preload(SFX_DIR + "fishing_cast.wav")
const BAIT_LANDS: AudioStream = preload(SFX_DIR + "fishing_bait_lands_inwater.wav")
const HOOKED: AudioStream = preload(SFX_DIR + "fishing_hooked.wav")
const REEL_IN: AudioStream = preload(SFX_DIR + "fishing_reel_in.wav")         ## the line coming back in with nothing on it
const REELING: AudioStream = preload(SFX_DIR + "fishing_reeling_in_with_fish.wav")   ## the tug-of-war, looped while it lasts
const PITCH_VARIANCE := 0.04
const REEL_QUIET_DB := -9.0    ## reel loop volume while the zone is off the fish...
const REEL_LOUD_DB := 0.0      ## ...and while it's on it
const REEL_QUIET_PITCH := 0.94
const REEL_LOUD_PITCH := 1.04

var world: Node            ## where one-shots are parented (set by the session)
var _reel_loop: AudioStreamPlayer

func cast(at: Vector3) -> void:
	_play(CAST, at)

func bait_lands(at: Vector3) -> void:
	_play(BAIT_LANDS, at)

func hooked(at: Vector3) -> void:
	_play(HOOKED, at)

func reel_in(at: Vector3) -> void:
	_play(REEL_IN, at)

## Starts the tug-of-war loop (no-op if it's already going).
func start_reel_loop() -> void:
	if _reel_loop != null:
		return
	_reel_loop = AudioStreamPlayer.new()
	_reel_loop.stream = REELING
	_reel_loop.bus = &"SFX"
	_reel_loop.volume_db = REEL_QUIET_DB
	_reel_loop.pitch_scale = REEL_QUIET_PITCH
	_reel_loop.finished.connect(_reel_loop.play)   # the wav has no loop flag: restart it
	add_child(_reel_loop)
	_reel_loop.play()

## Louder and a touch higher while the zone is on the fish. `amount` is 0..1.
func set_reel_intensity(amount: float) -> void:
	if _reel_loop == null:
		return
	_reel_loop.volume_db = lerpf(REEL_QUIET_DB, REEL_LOUD_DB, amount)
	_reel_loop.pitch_scale = lerpf(REEL_QUIET_PITCH, REEL_LOUD_PITCH, amount)

func stop_reel_loop() -> void:
	if _reel_loop == null:
		return
	_reel_loop.finished.disconnect(_reel_loop.play)
	_reel_loop.queue_free()
	_reel_loop = null

func _play(stream: AudioStream, at: Vector3) -> void:
	var host := world if is_instance_valid(world) else get_parent()
	if host == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = &"SFX"
	p.pitch_scale = 1.0 + randf_range(-PITCH_VARIANCE, PITCH_VARIANCE)
	host.add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
