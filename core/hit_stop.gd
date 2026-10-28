class_name HitStop
extends RefCounted
## Brief freeze-frame for heavy impacts. Static — call HitStop.freeze(0.1).
## Slows the whole game (Engine.time_scale) for `duration` REAL seconds, then
## restores it. Overlapping calls extend rather than stack.

const FROZEN_SCALE := 0.03

static var _until_msec := 0
static var _active := false

static func freeze(duration: float, scale := FROZEN_SCALE) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	duration *= float(Settings.get_value(&"accessibility/hitstop"))   # Settings > Accessibility
	if tree == null or duration <= 0.0:
		return
	_until_msec = maxi(_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))
	Engine.time_scale = scale
	if _active:
		return
	_active = true
	_wait_and_restore(tree)

static func _wait_and_restore(tree: SceneTree) -> void:
	while Time.get_ticks_msec() < _until_msec:
		# process_always = true, ignore_time_scale = true: counts real time.
		await tree.create_timer(0.01, true, false, true).timeout
	Engine.time_scale = 1.0
	_active = false
