@tool
class_name RoofCat
extends Node3D
## A cat sitting on a roof or sill, watching the street: slow breathing, a swishing tail,
## twitching ears, and its head follows you when you come near. Place the node where it
## should sit (HouseExtras puts one on a roof); the body is built from CritterParts. Not
## solid, not talkable — the missing cat of the quest is a different cat.

@export var fur := Color(0.55, 0.55, 0.6)
@export var watch_radius := 12.0     ## it looks at you inside this distance
@export var sleeps_at_night := true  ## vanishes (goes indoors) when it is dark

var _rig: Dictionary
var _phase := 0.0
var _ear_flick := 0.0
var _look_yaw := 0.0

func _ready() -> void:
	_rig = CritterParts.cat(fur)
	add_child(_rig["root"])
	_phase = randf() * TAU
	if Engine.is_editor_hint():
		set_process(false)

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	var root: Node3D = _rig["root"]
	root.visible = not (sleeps_at_night and WorldClock.night_amount() > 0.8)
	if not root.visible:
		return
	(_rig["body"] as Node3D).scale.y = 1.15 + sin(t * 1.6) * 0.025   # breathing
	# tail: a slow S-curve swish that travels down its segments
	var tail: Array = _rig["tail"]
	for i in tail.size():
		(tail[i] as Node3D).rotation = Vector3(deg_to_rad(-28.0 if i == 0 else -8.0), sin(t * 1.4 - i * 0.7) * 0.28, 0.0)
	# ears: an occasional flick
	_ear_flick = maxf(_ear_flick - delta * 6.0, 0.0)
	if randf() < 0.25 * delta:
		_ear_flick = 1.0
	(_rig["left_ear"] as Node3D).rotation.z = sin(_ear_flick * PI) * 0.35
	# head: turns toward the player when they are near, otherwise drifts about
	var head: Node3D = _rig["head"]
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var target := sin(t * 0.3) * 0.5
	if player != null and player.global_position.distance_to(global_position) < watch_radius:
		var local := to_local(player.global_position)
		target = clampf(atan2(-local.x, -local.z), -1.2, 1.2)
	_look_yaw = lerp_angle(_look_yaw, target, 3.0 * delta)
	head.rotation.y = _look_yaw
