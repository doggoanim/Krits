extends Node
## Global looping-ambience singleton (autoload `Ambience`, see project.godot) —
## the bed of environmental sound under a level (dripping water, wind...), on its
## own "Ambience" bus so it has its own volume slider. Sibling of Music, but
## fades in and out and is claimed by an owner: a level's LevelAmbience node
## plays its stream with itself as owner and only stops it if it still owns it,
## so a level swap (new level's node starts before the old one leaves the tree)
## can never cut the new level's ambience short.

@export var bus := &"Ambience"
@export_range(0.0, 1.0) var volume_scale := 0.8   ## linear, on top of the stream and the bus
@export var fade_time := 1.2

const SILENT := 0.0001

var _player: AudioStreamPlayer
var _owner: Object
var _fade := 0.0     ## 0 = silent, 1 = full
var _target := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps going under pause menus
	_player = AudioStreamPlayer.new()
	_player.bus = bus
	_player.finished.connect(_on_finished)
	add_child(_player)
	set_process(false)

func _process(delta: float) -> void:
	_fade = move_toward(_fade, _target, delta / maxf(fade_time, 0.01))
	_player.volume_db = linear_to_db(maxf(volume_scale * _fade, SILENT))
	if _fade <= 0.0 and _target <= 0.0:
		_player.stop()
		_player.stream = null
		set_process(false)

## Starts `stream` (looping) for `who`. Re-asking for the stream already
## playing just keeps it going (and takes over ownership).
func play(stream: AudioStream, who: Object) -> void:
	if stream == null:
		return
	_owner = who
	_target = 1.0
	if _player.stream != stream:
		_player.stream = stream
		_set_loop(stream)
		_fade = 0.0
		_player.volume_db = linear_to_db(SILENT)
		_player.play()
	elif not _player.playing:
		_player.play()
	set_process(true)

## Fades the ambience out, but only if `who` is still the one playing it.
func stop(who: Object) -> void:
	if who != _owner:
		return
	_owner = null
	_target = 0.0
	set_process(true)

func _on_finished() -> void:
	if _player.stream != null:   # streams without a loop flag just restart
		_player.play()

## Asks the stream itself to loop, for a gapless seam.
static func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
