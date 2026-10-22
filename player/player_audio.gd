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
## The orb attack additionally climbs in base pitch with the combo count
## (see play_orb_attack()), with the usual small random variance on top of
## wherever that base lands.

const SFX_DIR := "res://sounds/SFX/"

const JUMP_SFX: AudioStream = preload(SFX_DIR + "jump.wav")
const LONG_JUMP_SFX: AudioStream = preload(SFX_DIR + "long_jump.wav")
const WALL_BOUNCE_SFX: AudioStream = preload(SFX_DIR + "wall_bounce.wav")
const ROLL_BOUNCE_SFX: AudioStream = preload(SFX_DIR + "roll_bounce.wav")
const ORB_ATTACK_SFX: AudioStream = preload(SFX_DIR + "attack_orb.wav")
const SIDE_FLIP_SFX: AudioStream = preload(SFX_DIR + "side_flip.wav")
const SKID_SFX: AudioStream = preload(SFX_DIR + "skid.wav")
const CLIMB_SFX: AudioStream = preload(SFX_DIR + "climb.wav")
## The ground pound's three phases: windup starting, the slam launching
## downward, and the impact on landing — see PoundState/PoundLandState.
const POUND_READY_SFX: AudioStream = preload(SFX_DIR + "ground_pound_ready.wav")
const POUND_JUMP_SFX: AudioStream = preload(SFX_DIR + "ground_pound_jump.wav")
const POUND_LAND_SFX: AudioStream = preload(SFX_DIR + "ground_pound_land.wav")

const AIR_DIVE_SFX: Array[AudioStream] = [
	preload(SFX_DIR + "air_dive_1.wav"),
	preload(SFX_DIR + "air_dive_2.wav"),
]
const FOOTSTEP_SFX: Array[AudioStream] = [
	preload(SFX_DIR + "footsteps_grass_1.wav"),
	preload(SFX_DIR + "footsteps_grass_2.wav"),
	preload(SFX_DIR + "footsteps_grass_3.wav"),
	preload(SFX_DIR + "footsteps_grass_4.wav"),
	preload(SFX_DIR + "footsteps_grass_5.wav"),
	preload(SFX_DIR + "footsteps_grass_6.wav"),
	preload(SFX_DIR + "footsteps_grass_7.wav"),
]
## Four alternate full takes of the same continuous tumble loop (not short
## one-shots to fire repeatedly like footsteps) — one is picked at random
## when a roll starts and plays for the roll's whole duration. See
## set_rolling().
const ROLL_SFX: Array[AudioStream] = [
	preload(SFX_DIR + "roll_1.wav"),
	preload(SFX_DIR + "roll_2.wav"),
	preload(SFX_DIR + "roll_3.wav"),
	preload(SFX_DIR + "roll_4.wav"),
]

## Quietest/lowest-pitched at roll_stop_speed, full volume/pitch at
## roll_speed — see set_rolling()'s speed_ratio param.
const ROLL_MIN_VOLUME_DB := -16.0
const ROLL_MIN_PITCH := 0.85
const ROLL_MAX_PITCH := 1.15

## +/- this fraction of normal pitch, picked fresh each play — "slight"
## variety, not a cartoonish chipmunk/demon range.
const PITCH_VARIANCE := 0.08

## Orb attack pitch climbs with the combo (so a long chain audibly ramps up),
## capped well short of chipmunk territory for a very long combo.
const ORB_COMBO_PITCH_STEP := 0.12   ## added per combo step past the first
const ORB_COMBO_PITCH_MAX := 2.2

## The rolling loop's own player — persistent and toggled on/off for the
## whole duration of a roll, same "built once, _ready()" idiom PlayerEffects
## uses for its continuous particle emitters (running dust, trails), rather
## than the fire-and-forget _play() pattern every other sound here uses.
var _roll_player: AudioStreamPlayer3D

func _ready() -> void:
	_roll_player = AudioStreamPlayer3D.new()
	add_child(_roll_player)
	# Loop each take itself rather than relying on its .wav import settings
	# already having loop enabled — guarantees it regardless of how the file
	# was authored/imported.
	for stream in ROLL_SFX:
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

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

## `combo` is Arena's running combo count (1 on the first hit of a chain).
func play_orb_attack(combo := 1) -> void:
	var base_pitch := minf(1.0 + float(maxi(combo, 1) - 1) * ORB_COMBO_PITCH_STEP, ORB_COMBO_PITCH_MAX)
	_play(ORB_ATTACK_SFX, PITCH_VARIANCE, base_pitch)

func play_footstep() -> void:
	_play(FOOTSTEP_SFX.pick_random(), PITCH_VARIANCE)

func play_side_flip() -> void:
	_play(SIDE_FLIP_SFX, PITCH_VARIANCE)

func play_skid() -> void:
	_play(SKID_SFX, PITCH_VARIANCE)

func play_climb() -> void:
	_play(CLIMB_SFX, PITCH_VARIANCE)

## Continuous tumble loop for RollState, toggled on/off like a particle
## emitter rather than fired per-call. `active` starts/stops it; while active,
## `speed_ratio` (0..1, the caller's own current-speed-vs-roll-speed mix —
## see RollState) continuously fades volume and pitch, so the loop actually
## tracks how fast the roll currently is instead of playing flat throughout.
## The specific take is picked once per roll (not re-rolled every call) since
## these are full continuous loops, not short one-shots to vary every repeat.
func set_rolling(active: bool, speed_ratio := 0.0) -> void:
	if active:
		if not _roll_player.playing:
			_roll_player.stream = ROLL_SFX.pick_random()
			_roll_player.play()
		var t := clampf(speed_ratio, 0.0, 1.0)
		_roll_player.volume_db = lerpf(ROLL_MIN_VOLUME_DB, 0.0, t)
		_roll_player.pitch_scale = lerpf(ROLL_MIN_PITCH, ROLL_MAX_PITCH, t)
	elif _roll_player.playing:
		_roll_player.stop()

func play_pound_ready() -> void:
	_play(POUND_READY_SFX, PITCH_VARIANCE)

func play_pound_jump() -> void:
	_play(POUND_JUMP_SFX, PITCH_VARIANCE)

func play_pound_land() -> void:
	_play(POUND_LAND_SFX, PITCH_VARIANCE)

func _play(stream: AudioStream, pitch_variance: float, base_pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.pitch_scale = base_pitch + randf_range(-pitch_variance, pitch_variance)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
