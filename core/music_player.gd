extends Node
## Global background-music singleton (autoload `Music`, see project.godot) —
## one looping AudioStreamPlayer, with play()/stop() driven by whatever
## decides what track fits the moment (currently Main._apply_level_lighting,
## which maps a level to its track; see world/chesburg.tscn's music there).
## Centralized here, not on Main itself, so anything else that wants to
## change the music later (a cutscene, a boss fight) has one obvious place
## to call into, and the music keeps playing across level swaps that don't
## ask for a change rather than restarting with every scene load.

@export var bus := &"Music"

## Linear scale on top of whatever the track's own file volume already is —
## 1.0 = unchanged, 0.5 = half as loud. Converted to dB for AudioStreamPlayer
## (which only takes volume_db) via linear_to_db() below. Tucked down for
## now since the music was coming in too loud over everything else; raise
## it back toward 1.0 once the rest of the mix is tuned.
@export_range(0.0, 1.0) var volume_scale := 0.5

## While a menu is open the game is paused, but the music keeps playing —
## muffled (lowpass on the Music bus) and a little quieter, easing in and out.
@export var menu_cutoff_hz := 900.0
@export_range(0.0, 1.0) var menu_volume_mult := 0.75
@export var menu_blend_speed := 6.0

const OPEN_CUTOFF_HZ := 20500.0   ## lowpass fully open = no audible effect

var _player: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _blend := 0.0   ## 0 = normal, 1 = fully muffled (menu open)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep playing while a menu pauses the tree
	var bus_idx := AudioServer.get_bus_index(bus)
	if bus_idx != -1:
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = OPEN_CUTOFF_HZ
		AudioServer.add_bus_effect(bus_idx, _lowpass)
	_player = AudioStreamPlayer.new()
	_player.bus = bus
	_player.volume_db = linear_to_db(volume_scale)
	_player.finished.connect(_on_finished)
	add_child(_player)

func _process(delta: float) -> void:
	var target := 1.0 if MenuBase.open_menu != null else 0.0
	_blend = move_toward(_blend, target, menu_blend_speed * delta)
	if _lowpass:
		# Interpolate in log space so the sweep sounds even.
		_lowpass.cutoff_hz = exp(lerpf(log(OPEN_CUTOFF_HZ), log(menu_cutoff_hz), _blend))
	_player.volume_db = linear_to_db(volume_scale * lerpf(1.0, menu_volume_mult, _blend))

## Starts `stream` looping from the top. A no-op if it's already the track
## playing, so callers can call this every frame/level-load without
## restarting the track each time.
func play(stream: AudioStream) -> void:
	if stream == null or _player.stream == stream:
		return
	_player.stream = stream
	_player.play()

func stop() -> void:
	_player.stream = null
	_player.stop()

## Loops by just restarting on its own `finished` signal rather than relying
## on the imported stream's own loop flag — works regardless of how any
## given .ogg was imported, and keeps looping entirely this script's concern.
func _on_finished() -> void:
	if _player.stream:
		_player.play()
