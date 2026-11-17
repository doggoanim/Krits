class_name LevelAmbience
extends Node
## Drop into a level to give it a looping ambience bed (Ambience autoload, own
## volume slider in the audio settings). It starts when the level enters the
## scene and fades out when the level leaves.
##
## `day_only` makes it a daytime bed: it fades out at dusk and back in at dawn
## (by WorldClock), leaving the night to whatever else the level layers on top
## (AmbienceLayers' crickets).

@export var stream: AudioStream
@export var day_only := false
@export_range(0.0, 1.0) var day_threshold := 0.25   ## day_amount() above this counts as daytime

var _playing := false

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	set_process(day_only)
	if not day_only or _is_day():
		_start()

func _process(_delta: float) -> void:
	var day := _is_day()
	if day and not _playing:
		_start()
	elif not day and _playing:
		_stop()

func _is_day() -> bool:
	return WorldClock.day_amount() > day_threshold

func _start() -> void:
	_playing = true
	Ambience.play(stream, self)

func _stop() -> void:
	_playing = false
	Ambience.stop(self)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		Ambience.stop(self)
