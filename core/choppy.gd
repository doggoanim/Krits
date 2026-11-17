class_name Choppy
extends RefCounted
## The game's "stepped" animation clock. Blender's stepped interpolation holds each pose for
## a few frames instead of blending between keys, which is what gives the hand-animated
## characters their snappy, choppy feel; everything animated in code (critters, swaying
## cloth and signs, flame flicker, walking bobs...) asks this class for its time, so it holds
## poses the same way and the whole world matches.
##
## One setting: STEP_FRAMES frames of a FRAME_RATE-fps timeline per pose (2 frames at 24 fps
## = "on 2s" = 12 poses a second). Change it here to make everything choppier or
## smoother. The shaders (flame, cloth, sky) keep their own copy of STEP_SECONDS — if you
## change it here, change `STEP_SECONDS` at the top of shading/flame.gdshader,
## cloth_wind.gdshader and the sky shader as well.

const STEP_FRAMES := 2
const FRAME_RATE := 24.0
const STEP_SECONDS := STEP_FRAMES / FRAME_RATE

## Index of the pose being held right now (goes up by one every STEP_SECONDS).
static func index() -> int:
	return int(Time.get_ticks_msec() / 1000.0 / STEP_SECONDS)

## The current time, rounded down to the start of the pose being held.
static func time() -> float:
	return index() * STEP_SECONDS

## `t` seconds on an animation clock, rounded down to a pose.
static func snap(t: float) -> float:
	return floorf(t / STEP_SECONDS) * STEP_SECONDS

## Particle systems' fixed_fps that matches (they re-simulate this many times a second).
static func particle_fps() -> int:
	return maxi(int(roundf(FRAME_RATE / STEP_FRAMES)), 1)
