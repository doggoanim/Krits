extends Node
## Autoload `WorldClock`: the game's time of day. One in-game day lasts
## `day_length` real seconds; everything that cares about the hour (sun and
## sky: world/time_of_day.gd, lit windows: world/night_lamp.gd, NPC routines:
## world/npc_schedule.gd, sounds: world/ambience_layers.gd, ...) just asks this
## singleton, so none of them need to know about each other.
##
## It lives outside any level, so the clock keeps running while you are inside
## a house and the street looks the way it should when you step back out.
## Like everything else it stops while the game is paused.
##
## Handy while testing (debug console / a one-off script):
##   WorldClock.set_hour(21.0)     jump to 21:00
##   WorldClock.time_scale = 20.0  watch the day fly by

signal hour_changed(hour: int)   ## the whole hour just ticked over (0..23)

@export var day_length := 600.0       ## real seconds for one full 24h day
@export var start_hour := 9.0
@export var frozen := false           ## true = time stands still (cutscenes, tests)
var time_scale := 1.0

## Current time in hours, 0.0 <= hour < 24.0 (13.5 = 13:30).
var hour := 9.0

## Daylight window: dark before DAWN_START, full day from DAWN_END to DUSK_START,
## dark again after DUSK_END. Everything else is derived from these four numbers.
const DAWN_START := 5.0
const DAWN_END := 7.5
const DUSK_START := 17.5
const DUSK_END := 20.0

var _last_hour := -1

func _ready() -> void:
	hour = start_hour
	_last_hour = int(hour)

func _process(delta: float) -> void:
	if frozen:
		return
	hour = fposmod(hour + delta * time_scale * 24.0 / maxf(day_length, 1.0), 24.0)
	var whole := int(hour)
	if whole != _last_hour:
		_last_hour = whole
		hour_changed.emit(whole)

func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_last_hour = int(hour)
	hour_changed.emit(_last_hour)

## 0 at night .. 1 in full daylight, easing through dawn and dusk.
func day_amount() -> float:
	return smoothstep(DAWN_START, DAWN_END, hour) * (1.0 - smoothstep(DUSK_START, DUSK_END, hour))

func night_amount() -> float:
	return 1.0 - day_amount()

## How lit lanterns/windows should be: off in daylight, fully on once it is properly dark.
func lamp_amount() -> float:
	return clampf((night_amount() - 0.2) / 0.5, 0.0, 1.0)

func is_night() -> bool:
	return night_amount() > 0.5

## True while `from` <= hour < `to`; wraps midnight (22 -> 6 is a night shift).
func in_range(from: float, to: float) -> bool:
	if from <= to:
		return hour >= from and hour < to
	return hour >= from or hour < to

## "09:30" — for debug overlays and "opens at" hints.
func time_string() -> String:
	return "%02d:%02d" % [int(hour), int((hour - floorf(hour)) * 60.0)]

## Coarse part of the day, for lines of dialogue and barks: &"morning" / &"day" / &"evening" / &"night".
func period() -> StringName:
	if hour >= 5.0 and hour < 11.0:
		return &"morning"
	if hour >= 11.0 and hour < 17.0:
		return &"day"
	if hour >= 17.0 and hour < 21.0:
		return &"evening"
	return &"night"
