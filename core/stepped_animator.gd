class_name SteppedAnimator
extends Node
## Makes an AnimationPlayer play in held poses (see Choppy), like all the hand-animated
## characters: the clips only move on a new pose, advanced by exactly one STEP_SECONDS per
## step that went by, so the poses are evenly spaced whatever the frame time does.
## Movement of the node carrying the model stays smooth; only the clip's pose is held.
##
##   SteppedAnimator.attach(anim_player)    # once, after finding the AnimationPlayer
##
## Starting a clip is not held: the first pose of the new clip (and the start of its blend) is
## shown at once, so changing animation never waits for the next step.
##
## Skipped in the editor (the preview stays smooth, and nothing is saved into the scene).

const MAX_CATCH_UP := 4   ## a long hitch doesn't skip a whole cycle

var _anim: AnimationPlayer
var _step := -1

static func attach(anim: AnimationPlayer) -> SteppedAnimator:
	if anim == null or Engine.is_editor_hint():
		return null
	for child in anim.get_children():
		if child is SteppedAnimator:
			return child as SteppedAnimator
	var s := SteppedAnimator.new()
	s.name = "SteppedAnimator"
	s._anim = anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.add_child(s)
	anim.animation_started.connect(s._on_animation_started)
	return s

func _process(_delta: float) -> void:
	if not is_instance_valid(_anim):
		return
	var step := Choppy.index()
	if _step < 0:
		_step = step
		return
	if step == _step:
		return
	var steps := mini(step - _step, MAX_CATCH_UP)
	_step = step
	_anim.advance(Choppy.STEP_SECONDS * steps)

## A new clip begins: show one step of it straight away instead of holding the old pose
## until the next step comes round.
func _on_animation_started(_clip: StringName) -> void:
	if not is_instance_valid(_anim):
		return
	_step = Choppy.index()
	_anim.advance(Choppy.STEP_SECONDS)
