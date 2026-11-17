@tool
class_name WindChimes
extends Node3D
## Wind chimes that answer the shared gust field: when a gust of wind arrives
## (WindGusts.sample rising past `trigger_level`) the tubes swing and a few clear notes
## ring out, then it falls quiet again until the next gust. The mesh is built by
## HouseProps.wind_chimes(); this node only animates the child called "Swing".

@export var trigger_level := 1.35       ## gust strength (WindGusts.BASE_LEVEL..PEAK) that sets them off
@export var volume_db := -12.0
@export var max_distance := 22.0
@export var cooldown := 5.0             ## seconds before they can ring again

var _swing: Node3D
var _was_above := false
var _cool := 0.0
var _swing_amount := 0.0
var _phase := 0.0

func _ready() -> void:
	_swing = get_node_or_null("Swing") as Node3D
	_phase = randf() * TAU
	if Engine.is_editor_hint():
		set_process(false)

func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	var p := global_position
	var t := Time.get_ticks_msec() / 1000.0
	var gust := WindGusts.sample(Vector2(p.x, p.z), t)
	var above := gust > trigger_level
	if above and not _was_above and _cool <= 0.0:
		_ring()
		_cool = cooldown
	_was_above = above
	# sway follows the gust, with a little extra after a ring that dies away
	_swing_amount = lerpf(_swing_amount, clampf((gust - 0.5) / 1.3, 0.0, 1.0), 1.5 * delta)
	if _swing != null:
		_swing.rotation = Vector3(sin(t * 2.1 + _phase) * 0.12, 0.0, sin(t * 1.7 + _phase * 1.3) * 0.16) * (0.25 + _swing_amount * 1.4)

func _ring() -> void:
	var notes := randi_range(2, 4)
	for i in notes:
		get_tree().create_timer(i * randf_range(0.18, 0.4)).timeout.connect(_play_note)

func _play_note() -> void:
	if not is_inside_tree():
		return
	var stream := load(HouseProps.CHIME_SFX[randi() % HouseProps.CHIME_SFX.size()]) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db + randf_range(-3.0, 0.0)
	player.unit_size = 5.0
	player.max_distance = max_distance
	player.pitch_scale = randf_range(0.97, 1.03)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
