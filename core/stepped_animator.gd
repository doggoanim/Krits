class_name SteppedAnimator
extends Node
## Makes an AnimationPlayer play in held poses (see Choppy), like all the hand-animated
## characters: the clips only move on a new pose, advanced by exactly one STEP_SECONDS per
## step that went by, so the poses are evenly spaced whatever the frame time does.
## Movement of the node carrying the model stays smooth; only the clip's pose is held.
##
##   SteppedAnimator.attach(anim_player)                  # every clip held
##   SteppedAnimator.attach(anim_player, [&"run"])        # only these clips held, the rest smooth
##
## The held pose is re-applied every frame (advance by zero), so smooth effects layered on the
## skeleton, like squash and stretch, always sit on top of the right pose.
##
## Starting a clip is not held: the first pose of the new clip (and the start of its blend) is
## shown at once, so changing animation never waits for the next step.
##
## Skipped in the editor (the preview stays smooth, and nothing is saved into the scene).

const MAX_CATCH_UP := 4   ## a long hitch doesn't skip a whole cycle
const QUICK_START_GAP_MSEC := 250   ## clips restarting faster than this (e.g. jump <-> fall flicker) don't get the instant first pose, which would pop

var _anim: AnimationPlayer
var _only: Array[StringName] = []   ## empty = every clip is held; otherwise only these
var _step := -1
var _last_start_msec := -100000

static func attach(anim: AnimationPlayer, only_clips: Array[StringName] = []) -> SteppedAnimator:
	if anim == null or Engine.is_editor_hint():
		return null
	for child in anim.get_children():
		if child is SteppedAnimator:
			return child as SteppedAnimator
	var s := SteppedAnimator.new()
	s._only = only_clips
	s.name = "SteppedAnimator"
	s._anim = anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.add_child(s)
	anim.animation_started.connect(s._on_animation_started)
	return s

func _is_held(clip: StringName) -> bool:
	return _only.is_empty() or _only.has(clip)

func _process(delta: float) -> void:
	if not is_instance_valid(_anim):
		return
	if not _is_held(_anim.current_animation):
		_step = Choppy.index()
		_anim.advance(delta)   # a smooth clip: plays normally
		return
	var step := Choppy.index()
	if _step < 0:
		_step = step
		return
	if step == _step:
		# Same held pose: write it to the skeleton again anyway. Modifiers that run on top of the
		# animation every frame (the squash and stretch) start from a freshly reset skeleton, so a
		# frame where the animation wrote nothing would show them on the bare rest pose and pop.
		_anim.advance(0.0)
		return
	var steps := mini(step - _step, MAX_CATCH_UP)
	_step = step
	_anim.advance(Choppy.STEP_SECONDS * steps)

## A new clip begins: show one step of it straight away instead of holding the old pose
## until the next step comes round.
func _on_animation_started(clip: StringName) -> void:
	if not is_instance_valid(_anim) or not _is_held(clip):
		return
	var now := Time.get_ticks_msec()
	var quick := now - _last_start_msec < QUICK_START_GAP_MSEC
	_last_start_msec = now
	if quick:
		return   # clips switching back and forth: let the normal steps carry it, no pop
	_step = Choppy.index()
	_anim.advance(Choppy.STEP_SECONDS)
