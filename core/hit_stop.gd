class_name HitStop
extends RefCounted
## Brief freeze-frame for heavy impacts. Static — call HitStop.freeze(0.1).
## Slows the whole game (Engine.time_scale) AND all audio (music + sfx, via
## AudioServer.playback_speed_scale) for `duration` REAL seconds, then
## restores it. Overlapping calls extend rather than stack.
##
## Extras:
##   - impact frame: a quick white flash at the start of a freeze
##     (Settings > Accessibility > "Hit-Stop Flash").
##   - finisher(): a longer hold that then eases back up to normal speed
##     (picture and sound together) — used for the hit that ends a fight.

const FROZEN_SCALE := 0.03
const AUDIO_FROZEN_SCALE := 0.01   ## ~paused; AudioServer dislikes exactly 0
const FLASH_ALPHA := 0.55
const FLASH_TIME := 0.12
const FINISHER_HOLD := 0.4
const FINISHER_FADE := 0.8

static var _until_msec := 0
static var _fade_sec := 0.0        ## ease-out length after the hold (0 = snap back)
static var _active := false
static var _flash: ColorRect
static var _flash_tween: Tween

static func freeze(duration: float, scale := FROZEN_SCALE) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	duration *= float(Settings.get_value(&"accessibility/hitstop"))   # Settings > Accessibility
	if tree == null or duration <= 0.0:
		return
	_extend(tree, duration)
	_start(tree, scale)

## The killing blow of a fight: long hold, then a smooth return to speed.
## Safe to call before or after the hit's own freeze() — the two merge.
static func finisher(hold := FINISHER_HOLD, fade := FINISHER_FADE) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var mult := float(Settings.get_value(&"accessibility/hitstop"))
	if tree == null or mult <= 0.0:
		return
	_fade_sec = fade
	_extend(tree, hold * mult)
	_start(tree, FROZEN_SCALE)

static func _extend(_tree: SceneTree, duration: float) -> void:
	_until_msec = maxi(_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))

static func _start(tree: SceneTree, scale: float) -> void:
	_set_speed(scale, AUDIO_FROZEN_SCALE)
	_show_flash(tree)
	if _active:
		return
	_active = true
	_run(tree, scale)

static func _set_speed(game: float, audio: float) -> void:
	Engine.time_scale = game
	AudioServer.playback_speed_scale = audio

static func _run(tree: SceneTree, scale: float) -> void:
	while true:
		var now := Time.get_ticks_msec()
		if now < _until_msec:
			_set_speed(scale, AUDIO_FROZEN_SCALE)   # hold
		else:
			var t := 1.0 if _fade_sec <= 0.0 else float(now - _until_msec) / (_fade_sec * 1000.0)
			if t >= 1.0:
				break
			var e := t * t * (3.0 - 2.0 * t)   # smoothstep
			_set_speed(lerpf(scale, 1.0, e), lerpf(AUDIO_FROZEN_SCALE, 1.0, e))
		# process_always = true, ignore_time_scale = true: counts real time.
		await tree.create_timer(0.01, true, false, true).timeout
	_set_speed(1.0, 1.0)
	_fade_sec = 0.0
	_active = false

# ---------------------------------------------------------------- impact frame

static func _show_flash(tree: SceneTree) -> void:
	if not bool(Settings.get_value(&"accessibility/hitstop_flash")):
		return
	if _flash == null or not is_instance_valid(_flash):
		var layer := CanvasLayer.new()
		layer.layer = 100
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		_flash = ColorRect.new()
		_flash.color = Color.WHITE
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_flash)
		tree.root.add_child(layer)
	if _flash_tween:
		_flash_tween.kill()
	_flash.modulate.a = FLASH_ALPHA
	_flash_tween = _flash.create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, FLASH_TIME)
