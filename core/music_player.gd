extends Node
## Global background-music singleton (autoload `Music`, see project.godot) —
## one looping AudioStreamPlayer, with play()/stop() driven by whatever
## decides what track fits the moment (currently Main._apply_level_lighting,
## which maps a level to its track; see world/chesburg.tscn's music there).
## Centralized here, not on Main itself, so anything else that wants to
## change the music later (a cutscene, a boss fight) has one obvious place
## to call into, and the music keeps playing across level swaps that don't
## ask for a change rather than restarting with every scene load.

@export var bus := &"Master"

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = bus
	_player.finished.connect(_on_finished)
	add_child(_player)

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
