class_name AmbienceLayers
extends Node
## An extra looping sound bed on top of the level's own ambience (LevelAmbience), faded by the
## time of day: crickets once it is dark. (The daytime bed, birds included, is the level's own
## grassland ambience.) Plays on the Ambience bus (its volume slider), starts when the level
## enters the scene and stops when it leaves. Put one in an outdoor level.

## Leave empty for the default crickets loop.
@export var night_stream: AudioStream
@export var night_volume_db := -12.0
@export var fade_speed := 0.4              ## how fast (per second) the layer fades as the light changes
@export var bus := &"Ambience"

const SILENT_DB := -60.0
const NIGHT_DEFAULT := "res://sounds/Ambience/crickets_loop.ogg"

var _night: AudioStreamPlayer
var _night_level := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_night = _make_layer(night_stream if night_stream != null else load(NIGHT_DEFAULT) as AudioStream)

func _make_layer(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := stream.duplicate() as AudioStream   # a copy, so the loop flag doesn't leak onto the shared resource
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	p.stream = s
	p.bus = bus
	p.volume_db = SILENT_DB
	add_child(p)
	return p

func _process(delta: float) -> void:
	_night_level = move_toward(_night_level, WorldClock.night_amount(), fade_speed * delta)
	_drive(_night, _night_level, night_volume_db)

## A silent layer is stopped (no decoding cost); an audible one plays, volume following `level`.
func _drive(player: AudioStreamPlayer, level: float, volume_db: float) -> void:
	if level < 0.02:
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play(randf() * maxf(player.stream.get_length() - 0.1, 0.0))
	player.volume_db = volume_db + linear_to_db(level)
