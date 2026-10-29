class_name UiSfx
extends RefCounted
## Menu sounds (focus move, click). Static — call UiSfx.focus() / UiSfx.click().
## Plays through the SFX bus on a one-shot player parented to the scene root
## and set to process while paused, so it works inside the pause menu too.

const CLICK: AudioStream = preload("res://sounds/SFX/ui_click.wav")
const FOCUS: AudioStream = preload("res://sounds/SFX/ui_focus.wav")
const PITCH_VARIANCE := 0.05
const FOCUS_DEBOUNCE_MSEC := 60   ## menus grab focus on several controls at once when they open

static var _last_focus_msec := 0

static func click() -> void:
	_play(CLICK)

static func focus() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_focus_msec < FOCUS_DEBOUNCE_MSEC:
		return
	_last_focus_msec = now
	_play(FOCUS)

## The dialogue typewriter's tick — the focus sound with extra pitch wobble
## so a run of them reads as typing, not a machine gun. No debounce (the
## caller already thins them out).
static func blip() -> void:
	_play(FOCUS, 0.16)

static func _play(stream: AudioStream, pitch_variance := PITCH_VARIANCE) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"SFX"
	p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
