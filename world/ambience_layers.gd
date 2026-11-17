class_name AmbienceLayers
extends Node
## Extra looping sound beds on top of the level's own ambience (LevelAmbience), faded by the
## time of day: birdsong while it is light, crickets once it is dark. Both play on the
## Ambience bus (its volume slider), start when the level enters the scene and stop when it
## leaves. Put one in an outdoor level.

## Leave empty for the default birdsong / crickets loops.
@export var day_stream: AudioStream
@export var night_stream: AudioStream
@export var day_volume_db := -10.0
@export var night_volume_db := -12.0
@export var fade_speed := 0.4              ## how fast (per second) a layer fades as the light changes
@export var bus := &"Ambience"

const SILENT_DB := -60.0
const DAY_DEFAULT := "res://sounds/Ambience/birdsong_loop.ogg"
const NIGHT_DEFAULT := "res://sounds/Ambience/crickets_loop.ogg"

var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _day_level := 0.0
var _night_level := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_day = _make_layer(day_stream if day_stream != null else load(DAY_DEFAULT) as AudioStream)
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
	_day_level = move_toward(_day_level, WorldClock.day_amount(), fade_speed * delta)
	_night_level = move_toward(_night_level, WorldClock.night_amount(), fade_speed * delta)
	_drive(_day, _day_level, day_volume_db)
	_drive(_night, _night_level, night_volume_db)

## Silent layers are stopped (no decoding cost); audible ones play, volume following `level`.
func _drive(player: AudioStreamPlayer, level: float, volume_db: float) -> void:
	if level < 0.02:
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play(randf() * maxf(player.stream.get_length() - 0.1, 0.0))
	player.volume_db = volume_db + linear_to_db(level)
