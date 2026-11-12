extends Node
## Global background-music singleton (autoload `Music`, see project.godot) —
## one looping AudioStreamPlayer, with play()/stop() driven by whatever
## decides what track fits the moment (currently Main._apply_level_lighting,
## which maps a level to its track; see world/chesburg.tscn's music there).
## A track can come as a pair — the normal mix plus a battle mix of the same
## theme (Balatro-style). Both play in lockstep inside one
## AudioStreamSynchronized and only their volumes change: the battle layer
## fades in while Game.in_combat is true and out again when it ends, so the
## theme never restarts or drifts. Both files must be the same length/tempo.
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

## How long the normal <-> battle crossfade takes (seconds), each direction.
@export var battle_fade_in := 1.0
@export var battle_fade_out := 2.0

const OPEN_CUTOFF_HZ := 20500.0   ## lowpass fully open = no audible effect
const LAYER_NORMAL := 0
const LAYER_BATTLE := 1
const SILENT_DB := -80.0
const LENGTH_MISMATCH_WARN := 0.05   ## seconds

var _player: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var duck := false   ## set by anything that wants the music pushed way down for a moment (the item-get jingle)
@export_range(0.0, 1.0) var duck_volume_mult := 0.12
@export var duck_blend_speed := 5.0
var _duck_blend := 0.0
var force_muffle := false   ## set by anything that wants the muffled mix without a menu (e.g. the death sequence)
var _blend := 0.0   ## 0 = normal, 1 = fully muffled (menu open)
var _normal_stream: AudioStream
var _battle_stream: AudioStream
var _sync: AudioStreamSynchronized   ## only set while a normal+battle pair is playing
var _battle_mix := 0.0   ## 0 = normal layer only, 1 = battle layer only

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
	var target := 1.0 if (MenuBase.open_menu != null or force_muffle) else 0.0
	_blend = move_toward(_blend, target, menu_blend_speed * delta)
	if _lowpass:
		# Interpolate in log space so the sweep sounds even.
		_lowpass.cutoff_hz = exp(lerpf(log(OPEN_CUTOFF_HZ), log(menu_cutoff_hz), _blend))
	_duck_blend = move_toward(_duck_blend, 1.0 if duck else 0.0, duck_blend_speed * delta)
	_player.volume_db = linear_to_db(volume_scale * lerpf(1.0, menu_volume_mult, _blend) * lerpf(1.0, duck_volume_mult, _duck_blend))
	_update_battle_mix(delta)

## Starts `stream` looping from the top. Pass `battle_stream` to give the
## track a battle layer that fades in during combat. A no-op if that exact
## track (and battle layer) is already playing, so callers can call this
## every frame/level-load without restarting the track each time.
func play(stream: AudioStream, battle_stream: AudioStream = null) -> void:
	if stream == null:
		return
	if _normal_stream == stream and _battle_stream == battle_stream:
		return
	_normal_stream = stream
	_battle_stream = battle_stream
	_battle_mix = 1.0 if (battle_stream != null and Game.in_combat) else 0.0
	_sync = _build_layers(stream, battle_stream)
	_player.stream = _sync if _sync != null else stream
	_apply_layer_volumes()
	_player.play()

func stop() -> void:
	_normal_stream = null
	_battle_stream = null
	_sync = null
	_player.stream = null
	_player.stop()

## Both layers inside one synchronized stream; null when there is no battle layer.
func _build_layers(normal: AudioStream, battle: AudioStream) -> AudioStreamSynchronized:
	if battle == null:
		return null
	if absf(normal.get_length() - battle.get_length()) > LENGTH_MISMATCH_WARN:
		push_warning("Music: normal (%.2fs) and battle (%.2fs) tracks differ in length; they will drift apart on loop." \
				% [normal.get_length(), battle.get_length()])
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = 2
	sync.set_sync_stream(LAYER_NORMAL, normal)
	sync.set_sync_stream(LAYER_BATTLE, battle)
	return sync

## Eases the crossfade toward the current combat state.
func _update_battle_mix(delta: float) -> void:
	if _sync == null:
		return
	var fighting := Game.in_combat
	var target := 1.0 if fighting else 0.0
	var duration := battle_fade_in if fighting else battle_fade_out
	var step := delta / maxf(duration, 0.001)
	var next := move_toward(_battle_mix, target, step)
	if next != _battle_mix:
		_battle_mix = next
		_apply_layer_volumes()

## Equal-power crossfade so the overall loudness stays steady mid-fade.
func _apply_layer_volumes() -> void:
	if _sync == null:
		return
	var angle := _battle_mix * PI * 0.5
	_sync.set_sync_stream_volume(LAYER_NORMAL, maxf(linear_to_db(cos(angle)), SILENT_DB))
	_sync.set_sync_stream_volume(LAYER_BATTLE, maxf(linear_to_db(sin(angle)), SILENT_DB))

## Loops by just restarting on its own `finished` signal rather than relying
## on the imported stream's own loop flag — works regardless of how any
## given .ogg was imported, and keeps looping entirely this script's concern.
func _on_finished() -> void:
	if _player.stream:
		_player.play()
