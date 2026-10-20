class_name PlayerAudio
extends Node3D
## Movement sound effects. One AudioStreamPlayer3D per call, freed once it's
## done playing — same one-shot pattern as PlayerEffects' bursts, so
## overlapping plays (two footsteps in quick succession, say) never fight
## over a single shared player or cut each other off.
##
## Every sound gets a small random pitch_scale nudge for variety EXCEPT
## air dive and long jump, which stay at a fixed pitch — per design, those
## two reaction sounds should land the same every time instead of varying.
## A sound with more than one source file (air dive, footsteps) also picks a
## random sample each play, independent of whether its pitch varies.

const SFX_DIR := "res://sounds/SFX/"

const JUMP_SFX: AudioStream = preload(SFX_DIR + "jump.wav")
const LONG_JUMP_SFX: AudioStream = preload(SFX_DIR + "long_jump.wav")
const WALL_BOUNCE_SFX: AudioStream = preload(SFX_DIR + "wall_bounce.wav")
const ROLL_BOUNCE_SFX: AudioStream = preload(SFX_DIR + "roll_bounce.wav")
const ORB_ATTACK_SFX: AudioStream = preload(SFX_DIR + "attack_orb.wav")

const AIR_DIVE_SFX: Array[AudioStream] = [
	preload(SFX_DIR + "air_dive_1.wav"),
	preload(SFX_DIR + "air_dive_2.wav"),
]
const FOOTSTEP_SFX: Array[AudioStream] = [
	preload(SFX_DIR + "footsteps_grass_1.wav"),
	preload(SFX_DIR + "footsteps_grass_2.wav"),
	preload(SFX_DIR + "footsteps_grass_3.wav"),
]

## +/- this fraction of normal pitch, picked fresh each play — "slight"
## variety, not a cartoonish chipmunk/demon range.
const PITCH_VARIANCE := 0.08

func play_jump() -> void:
	_play(JUMP_SFX, PITCH_VARIANCE)

## Fixed pitch, by design — see the class doc comment above.
func play_long_jump() -> void:
	_play(LONG_JUMP_SFX, 0.0)

## Fixed pitch, but alternates between the two takes pushed for this one.
func play_air_dive() -> void:
	_play(AIR_DIVE_SFX.pick_random(), 0.0)

func play_wall_bounce() -> void:
	_play(WALL_BOUNCE_SFX, PITCH_VARIANCE)

func play_roll_bounce() -> void:
	_play(ROLL_BOUNCE_SFX, PITCH_VARIANCE)

func play_orb_attack() -> void:
	_play(ORB_ATTACK_SFX, PITCH_VARIANCE)

func play_footstep() -> void:
	_play(FOOTSTEP_SFX.pick_random(), PITCH_VARIANCE)

func _play(stream: AudioStream, pitch_variance: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
