@tool
class_name SmokeSchedule
extends Node
## Makes a chimney's smoke follow the household's day. Add as a CHILD of the smoke particles
## (HouseParts builds one into every smoking chimney): the chimney is cold while nobody is up,
## lights a thin wisp when the house wakes, and billows thicker around meal times.
##
## The household's routine is looked up by the house the chimney stands on (the PROFILES table
## below; houses missing from it use DEFAULT). Hours are WorldClock hours. The chimney's
## crackle loop (a "LoopSound" next to the smoke) fades with it.

## house node name -> [wake, sleep, meal hours...]. The baker rises early for the ovens.
const PROFILES := {
	"house_chesburg_1": [7.0, 22.5, 8.0, 19.0],
	"house_chesburg_2": [6.5, 22.5, 7.5, 12.5, 18.5],
	"house_chesburg_3": [7.0, 23.5, 8.0, 13.0, 19.5],
	"house_chesburg_4": [4.5, 20.0, 5.5, 8.0, 12.5, 18.5],
	"house_chesburg_5": [7.0, 21.0, 7.5, 12.5, 18.0],
	"house_chesburg_6": [6.5, 22.0, 7.5, 13.0, 19.0],
}
const DEFAULT := [7.0, 22.0, 8.0, 13.0, 19.0]

const BASE := 0.3            ## thin smoke from a banked fire while the house is up
const PEAK := 0.7            ## extra on top of that at the middle of a meal
const MEAL_WIDTH := 0.9      ## hours either side of a meal that the smoke is thickened
const RAMP := 0.5            ## hours to light up / bank down at the ends of the day
const UPDATE_SECONDS := 1.0
const MIN_ALPHA := 0.35
const MAX_ALPHA := 1.0
const SIZE_RANGE := Vector2(0.8, 1.4)   ## multiplier on the puffs' size, thin -> thick

var _smoke: CPUParticles3D
var _profile: Array = DEFAULT
var _base_scale := Vector2.ONE
var _loop: AudioStreamPlayer3D
var _loop_db := 0.0
var _timer := 0.0

func _ready() -> void:
	_smoke = get_parent() as CPUParticles3D
	if Engine.is_editor_hint() or _smoke == null:
		set_process(false)
		return
	_base_scale = Vector2(_smoke.scale_amount_min, _smoke.scale_amount_max)
	_profile = PROFILES.get(_house_name(), DEFAULT)
	_find_loop.call_deferred()
	_apply()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_SECONDS
		_apply()

func _house_name() -> String:
	var node: Node = _smoke
	while node != null:
		if String(node.name).begins_with("house_chesburg"):
			return String(node.name)
		node = node.get_parent()
	return ""

func _find_loop() -> void:
	var holder := _smoke.get_parent()
	if holder != null:
		_loop = holder.get_node_or_null("LoopSound") as AudioStreamPlayer3D
		if _loop != null:
			_loop_db = _loop.volume_db

## 0 (cold) .. 1 (full billow) at hour `h` for a profile [wake, sleep, meals...].
static func intensity(profile: Array, h: float) -> float:
	var wake: float = profile[0]
	var sleep: float = profile[1]
	if h < wake or h > sleep:
		return 0.0
	var ramp := minf(minf((h - wake) / RAMP, (sleep - h) / RAMP), 1.0)
	var level := BASE
	for i in range(2, profile.size()):
		var d: float = (h - float(profile[i])) / MEAL_WIDTH
		level += PEAK * exp(-d * d)
	return clampf(level, 0.0, 1.0) * ramp

func _apply() -> void:
	var k := intensity(_profile, WorldClock.hour)
	_smoke.emitting = k > 0.08
	_smoke.color = Color(1, 1, 1, lerpf(MIN_ALPHA, MAX_ALPHA, k))
	var size := lerpf(SIZE_RANGE.x, SIZE_RANGE.y, k)
	_smoke.scale_amount_min = _base_scale.x * size
	_smoke.scale_amount_max = _base_scale.y * size
	if _loop != null and is_instance_valid(_loop):
		_loop.volume_db = _loop_db + linear_to_db(maxf(k, 0.001))
