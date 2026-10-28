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
## Played when a weapon actually deals its damage (sword: on landing the
## combo; bow: when the stack is released; staff: when a spell is cast).
const SWORD_HIT_SFX: AudioStream = preload(SFX_DIR + "attack_orb_sword_hit.wav")
const BOW_HIT_SFX: AudioStream = preload(SFX_DIR + "attack_orb_bow_hit.wav")
const MAGIC_HIT_SFX: AudioStream = preload(SFX_DIR + "attack_orb_magic_hit.wav")
const HURT_SFX: Array[AudioStream] = [
	preload(SFX_DIR + "player_hurt_1.wav"),
	preload(SFX_DIR + "player_hurt_2.wav"),
	preload(SFX_DIR + "player_hurt_3.wav"),
]
const SIDE_FLIP_SFX: AudioStream = preload(SFX_DIR + "side_flip.wav")
const SKID_SFX: AudioStream = preload(SFX_DIR + "skid.wav")
const CLIMB_SFX: AudioStream = preload(SFX_DIR + "climb.wav")
const ROLL_START_SFX: AudioStream = preload(SFX_DIR + "roll_start.wav")
## The ground pound's three phases: windup starting, the slam launching
## downward, and the impact on landing — see PoundState/PoundLandState.
const POUND_READY_SFX: AudioStream = preload(SFX_DIR + "ground_pound_ready.wav")
const POUND_JUMP_SFX: AudioStream = preload(SFX_DIR + "ground_pound_jump.wav")
const POUND_LAND_SFX: AudioStream = preload(SFX_DIR + "ground_pound_land.wav")

const AIR_DIVE_SFX: Array[AudioStream] = [
	preload(SFX_DIR + "air_dive_1.wav"),
	preload(SFX_DIR + "air_dive_2.wav"),
]
const FOOTSTEPS_DIR := SFX_DIR + "footsteps/"

## Built-in defaults for the footstep_sfx_* exports below — pulled out as
## their own consts so Main (main.gd) can also use them as the default
## values of its own exported footstep_sfx_* vars, without duplicating these
## lists in two files.
const DEFAULT_FOOTSTEP_SFX_GRASS: Array[AudioStream] = [
	preload(FOOTSTEPS_DIR + "grass/footsteps_grass_1.wav"),
	preload(FOOTSTEPS_DIR + "grass/footsteps_grass_2.wav"),
	preload(FOOTSTEPS_DIR + "grass/footsteps_grass_3.wav"),
	preload(FOOTSTEPS_DIR + "grass/footsteps_grass_4.wav"),
	preload(FOOTSTEPS_DIR + "grass/footsteps_grass_5.wav"),
	preload(FOOTSTEPS_DIR + "grass/footsteps_grass_6.wav"),
	preload(FOOTSTEPS_DIR + "grass/footsteps_grass_7.wav"),
]
const DEFAULT_FOOTSTEP_SFX_DIRT: Array[AudioStream] = [
	preload(FOOTSTEPS_DIR + "dirt/footsteps_dirt_1.wav"),
	preload(FOOTSTEPS_DIR + "dirt/footsteps_dirt_2.wav"),
	preload(FOOTSTEPS_DIR + "dirt/footsteps_dirt_3.wav"),
	preload(FOOTSTEPS_DIR + "dirt/footsteps_dirt_4.wav"),
]
const DEFAULT_FOOTSTEP_SFX_ROCK: Array[AudioStream] = [
	preload(FOOTSTEPS_DIR + "rock/footsteps_rock_1.wav"),
	preload(FOOTSTEPS_DIR + "rock/footsteps_rock_2.wav"),
	preload(FOOTSTEPS_DIR + "rock/footsteps_rock_3.wav"),
	preload(FOOTSTEPS_DIR + "rock/footsteps_rock_4.wav"),
	preload(FOOTSTEPS_DIR + "rock/footsteps_rock_5.wav"),
	preload(FOOTSTEPS_DIR + "rock/footsteps_rock_6.wav"),
]
const DEFAULT_FOOTSTEP_SFX_WATER: Array[AudioStream] = [
	preload(FOOTSTEPS_DIR + "water/footsteps_water_1.wav"),
	preload(FOOTSTEPS_DIR + "water/footsteps_water_2.wav"),
	preload(FOOTSTEPS_DIR + "water/footsteps_water_3.wav"),
	preload(FOOTSTEPS_DIR + "water/footsteps_water_4.wav"),
	preload(FOOTSTEPS_DIR + "water/footsteps_water_5.wav"),
	preload(FOOTSTEPS_DIR + "water/footsteps_water_6.wav"),
]
const DEFAULT_FOOTSTEP_SFX_WOOD: Array[AudioStream] = [
	preload(FOOTSTEPS_DIR + "wood/footsteps_wood_1.wav"),
	preload(FOOTSTEPS_DIR + "wood/footsteps_wood_2.wav"),
	preload(FOOTSTEPS_DIR + "wood/footsteps_wood_3.wav"),
	preload(FOOTSTEPS_DIR + "wood/footsteps_wood_4.wav"),
	preload(FOOTSTEPS_DIR + "wood/footsteps_wood_5.wav"),
	preload(FOOTSTEPS_DIR + "wood/footsteps_wood_6.wav"),
]

## One array per FootstepSurfaces.Surface (see that file for how a surface
## is detected from whatever the player's standing on). @export rather than
## const so these are actually editable: PlayerAudio is built entirely in
## code (Player._ready() does `PlayerAudio.new()`) and never appears as its
## own node in a saved scene, so Main re-exports these three and pushes them
## down after creating Player — see main.gd's footstep_sfx_* exports. These
## defaults just mean the sounds still work if something ever builds a
## PlayerAudio without going through Main (e.g. a test scene).
##
## play_footstep() falls back to footstep_sfx_grass for any surface whose
## array ends up empty (e.g. if you clear one out in the Inspector), rather
## than playing nothing.
@export var footstep_sfx_grass: Array[AudioStream] = DEFAULT_FOOTSTEP_SFX_GRASS
@export var footstep_sfx_dirt: Array[AudioStream] = DEFAULT_FOOTSTEP_SFX_DIRT
@export var footstep_sfx_rock: Array[AudioStream] = DEFAULT_FOOTSTEP_SFX_ROCK
@export var footstep_sfx_water: Array[AudioStream] = DEFAULT_FOOTSTEP_SFX_WATER
@export var footstep_sfx_wood: Array[AudioStream] = DEFAULT_FOOTSTEP_SFX_WOOD
## Continuous swim stroke loop, same toggled-on/off idiom as ROLL_SFX/
## set_rolling() below — a const rather than another Main-wired @export like
## the footstep_sfx_* sets above, same reasoning as ROLL_SFX (a full
## continuous loop to pick once per swim, not a per-surface set anything else
## needs to override).
const SWIM_SFX: Array[AudioStream] = [
	preload(FOOTSTEPS_DIR + "water/swimming_1.wav"),
	preload(FOOTSTEPS_DIR + "water/swimming_2.wav"),
	preload(FOOTSTEPS_DIR + "water/swimming_3.wav"),
	preload(FOOTSTEPS_DIR + "water/swimming_4.wav"),
	preload(FOOTSTEPS_DIR + "water/swimming_5.wav"),
]
## Splashing in/out of a WaterVolume (see play_water_splash()) — two takes,
## picked at random each time like AIR_DIVE_SFX.
const WATER_SPLASH_SFX: Array[AudioStream] = [
	preload(SFX_DIR + "water_splash_1.wav"),
	preload(SFX_DIR + "water_splash_2.wav"),
]
## The `big` case (a fall from height, a ground pound into the water) gets
## its own dedicated recording instead of just a louder/lower-pitched take
## of WATER_SPLASH_SFX above — fixed pitch, same reasoning as AIR_DIVE_SFX/
## LONG_JUMP_SFX: a single heavy impact should land the same every time.
const BIG_WATER_SPLASH_SFX: AudioStream = preload(SFX_DIR + "big_water_splash.wav")
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
const SFX_BUS := &"SFX"   ## see default_bus_layout.tres

var _roll_player: AudioStreamPlayer3D

func _ready() -> void:
	_roll_player = AudioStreamPlayer3D.new()
	_roll_player.bus = SFX_BUS
	add_child(_roll_player)
	# Loop each take itself rather than relying on its .wav import settings
	# already having loop enabled — guarantees it regardless of how the file
	# was authored/imported. loop_begin/loop_end must be set explicitly too:
	# a freshly imported WAV with no embedded loop markers has both at 0, so
	# turning on loop_mode alone collapses the loop to a zero-length region
	# right at the very start — sounds like it never plays at all, instead of
	# looping the whole clip. get_length() * mix_rate gives the frame count
	# without needing format-specific math (8-bit/16-bit/ADPCM/QOA all differ
	# in bytes-per-frame, but get_length() already accounts for that).
	# SWIM_SFX is NOT looped like this — see play_swim_stroke()'s own
	# comment for why those stay one-shot.
	for stream in ROLL_SFX:
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(round(stream.get_length() * stream.mix_rate))

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

## The sound of a weapon's damage landing; `kind` is the equipped
## WeaponData.Kind. Sword hits pitch up slightly with the combo (`power`).
func play_damage_hit(kind: int, power := 1) -> void:
	match kind:
		WeaponData.Kind.BOW:
			_play(BOW_HIT_SFX, PITCH_VARIANCE)
		WeaponData.Kind.STAFF:
			_play(MAGIC_HIT_SFX, PITCH_VARIANCE)
		_:
			_play(SWORD_HIT_SFX, PITCH_VARIANCE, minf(1.0 + 0.03 * float(maxi(power, 1) - 1), 1.3))

func play_hurt() -> void:
	_play(HURT_SFX.pick_random(), PITCH_VARIANCE)

## `surface` comes from FootstepSurfaces.detect() — see GroundState, which
## raycasts straight down each step and passes whatever it finds through.
## Falls back to the grass set if nothing's recorded for that surface yet.
func play_footstep(surface := FootstepSurfaces.DEFAULT_SURFACE) -> void:
	var pool := _sfx_for(surface)
	if pool.is_empty():
		pool = footstep_sfx_grass
	_play(pool.pick_random(), PITCH_VARIANCE)

## Walking through water shallow enough to stay in GroundState (below
## config.water_swim_depth_ratio — see GroundState._play_footstep()), rather
## than the dirt/grass/rock set that location would otherwise get.
func play_water_footstep() -> void:
	var pool := footstep_sfx_water
	if pool.is_empty():
		pool = footstep_sfx_grass
	_play(pool.pick_random(), PITCH_VARIANCE)

func _sfx_for(surface: FootstepSurfaces.Surface) -> Array[AudioStream]:
	match surface:
		FootstepSurfaces.Surface.DIRT:
			return footstep_sfx_dirt
		FootstepSurfaces.Surface.ROCK:
			return footstep_sfx_rock
		FootstepSurfaces.Surface.WOOD:
			return footstep_sfx_wood
		_:
			return footstep_sfx_grass

func play_side_flip() -> void:
	_play(SIDE_FLIP_SFX, PITCH_VARIANCE)

func play_skid() -> void:
	_play(SKID_SFX, PITCH_VARIANCE)

func play_climb() -> void:
	_play(CLIMB_SFX, PITCH_VARIANCE)

## One-shot cue for the moment a roll begins, separate from set_rolling()'s
## continuous tumble loop — same "distinct launch sound" pattern as jump/dive.
func play_roll_start() -> void:
	_play(ROLL_START_SFX, PITCH_VARIANCE)

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

## One splash per stroke, timed to the swim animation's own phase — see
## SwimState._update_stroke_sfx(), the same "fire on a clip's own loop
## crossing a phase point" idiom GroundState._update_footsteps() uses for
## footsteps. One-shot and freshly randomized every call (same _play()
## pattern as play_footstep()) rather than a single looped ambient track:
## a continuous loop can only ever randomize once per swim (whenever it's
## (re)started), which reads as the same sound looping the whole time you're
## actually swimming — picking a fresh take each stroke instead fixes that.
func play_swim_stroke() -> void:
	_play(SWIM_SFX.pick_random(), PITCH_VARIANCE)

## Entering/exiting a WaterVolume (see WaterVolume._on_body_entered/_exited) —
## one call site for both since the splash sound doesn't need entering's
## distinction the way burst_water_splash()'s particle amount does.
## `big` (a fall from height, a ground pound into the water — see
## WaterVolume._on_body_entered()) plays louder and a bit lower-pitched, same
## "heavier impact" read as a ground-pound land vs. a plain footstep.
func play_water_splash(big := false) -> void:
	if big:
		_play(BIG_WATER_SPLASH_SFX, 0.0)
	else:
		_play(WATER_SPLASH_SFX.pick_random(), PITCH_VARIANCE)

func play_pound_ready() -> void:
	_play(POUND_READY_SFX, PITCH_VARIANCE)

func play_pound_jump() -> void:
	_play(POUND_JUMP_SFX, PITCH_VARIANCE)

func play_pound_land() -> void:
	_play(POUND_LAND_SFX, PITCH_VARIANCE)

func _play(stream: AudioStream, pitch_variance: float, base_pitch := 1.0, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.pitch_scale = base_pitch + randf_range(-pitch_variance, pitch_variance)
	p.volume_db = volume_db
	p.bus = SFX_BUS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
