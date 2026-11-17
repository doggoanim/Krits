class_name SpatialOneShots
extends Node3D
## Occasional sounds from a spot in the world: a hammer from a workshop, an axe at the wood
## pile. Every so often (random, between `min_gap` and `max_gap` seconds) it plays one of
## `streams` from here in 3D, but only while WorldClock is between `active_from` and
## `active_to` — the smith stops at sundown. Quiet beyond `max_distance`.

@export var streams: Array[AudioStream] = []
@export var min_gap := 12.0
@export var max_gap := 30.0
@export var active_from := 7.0
@export var active_to := 18.0
@export var volume_db := -4.0
@export var unit_size := 6.0
@export var max_distance := 40.0
@export var bus := &"Ambience"

var _wait := 0.0
var _player: AudioStreamPlayer3D

func _ready() -> void:
	if Engine.is_editor_hint() or streams.is_empty():
		set_process(false)
		return
	_player = AudioStreamPlayer3D.new()
	_player.bus = bus
	_player.volume_db = volume_db
	_player.unit_size = unit_size
	_player.max_distance = max_distance
	add_child(_player)
	_wait = randf_range(min_gap * 0.3, max_gap)

func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = randf_range(min_gap, max_gap)
	if not WorldClock.in_range(active_from, active_to) or _player.playing:
		return
	_player.stream = streams[randi() % streams.size()]
	_player.pitch_scale = randf_range(0.95, 1.05)
	_player.play()
