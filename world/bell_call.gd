class_name BellCall
extends Node
## The town bell that calls the player to the mayor's house (house 3) at the
## start of the game. While the story flag `bell_calling` is set and the player
## has not yet gone into the mayor's house (`entered_mayor_house`), the bell
## rings every RING_INTERVAL seconds:
##   * the sound plays through a "Bell" audio bus whose lowpass muffles it while
##     the player is indoors (set_indoors(), driven by Main per level) and opens
##     up the moment they step outside, and
##   * a shockwave bursts out from the level's "bell_point" node (a Marker3D on
##     top of house 3 in chesburg.tscn) so there is something to follow to it.
## Main creates one of these; start() begins the calling (the intro does that),
## and it carries on after a reload as long as the flags say so.

const RING_INTERVAL := 5.0
const BELL_SFX: AudioStream = preload("res://sounds/SFX/others/bell.wav")
const BUS_NAME := &"Bell"
const OPEN_CUTOFF_HZ := 20500.0
const MUFFLED_CUTOFF_HZ := 650.0
const MUFFLED_VOLUME_DB := -7.0
const BLEND_SPEED := 6.0
const CALLING_FLAG := &"bell_calling"
const DONE_FLAG := &"entered_mayor_house"
const POINT_GROUP := &"bell_point"
const SHOCKWAVE := preload("res://world/bell_shockwave.gd")

var _player: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _timer: Timer
var _indoors := false
var _blend := 1.0   ## 1 = fully muffled (indoors), 0 = open air

func _ready() -> void:
	_setup_bus()
	_player = AudioStreamPlayer.new()
	_player.stream = BELL_SFX
	_player.bus = BUS_NAME
	add_child(_player)
	_timer = Timer.new()
	_timer.wait_time = RING_INTERVAL
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	Events.story_flag_changed.connect(_on_flag_changed)
	if Game.flag(CALLING_FLAG) and not Game.flag(DONE_FLAG):
		_timer.start()   # a reloaded save mid-call: keep ringing (the first ring is one interval away)

## Begins the calling: rings now, then every RING_INTERVAL seconds.
func start() -> void:
	if Game.flag(DONE_FLAG):
		return
	Game.set_flag(CALLING_FLAG)
	ring()
	_timer.start()

func stop() -> void:
	_timer.stop()

## Muffled while the player is in a building; clear outdoors.
func set_indoors(indoors: bool) -> void:
	_indoors = indoors

func ring() -> void:
	_player.play()
	var point := get_tree().get_first_node_in_group(POINT_GROUP) as Node3D
	if point != null:
		var wave: Node3D = SHOCKWAVE.new()
		point.get_tree().current_scene.add_child(wave)
		wave.global_position = point.global_position

func _process(delta: float) -> void:
	_blend = move_toward(_blend, 1.0 if _indoors else 0.0, BLEND_SPEED * delta)
	if _lowpass != null:
		_lowpass.cutoff_hz = exp(lerpf(log(OPEN_CUTOFF_HZ), log(MUFFLED_CUTOFF_HZ), _blend))
	_player.volume_db = lerpf(0.0, MUFFLED_VOLUME_DB, _blend)

func _on_timeout() -> void:
	if Game.flag(DONE_FLAG):
		stop()
		return
	ring()

func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag == DONE_FLAG:
		stop()

## A dedicated bus so only the bell gets the muffle, sent on through SFX.
func _setup_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, &"SFX")
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = OPEN_CUTOFF_HZ
		AudioServer.add_bus_effect(idx, _lowpass)
	else:
		_lowpass = AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
