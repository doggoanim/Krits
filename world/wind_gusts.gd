class_name WindGusts
extends RefCounted
## A shared gust field, sampled by FoliageWind (and AmbientMotes) so every
## planted prop gusts together instead of each swaying to its own
## independent, unrelated rhythm — real wind sweeps across a whole field at
## once, not clump by clump. Pure function of world position + time, so
## nothing needs to stay wired to anything else to use it; any system that
## wants to feel the same wind just calls sample() each frame.
##
## The gust itself is a single smooth bump per GUST_PERIOD seconds (idle at
## BASE_LEVEL the rest of the time, not a constant hum), and that bump's
## phase is offset by world-space X — so it visibly reads as a front
## traveling across the level along X at TRAVEL_SPEED, arriving at props
## further along a little later than ones near X=0, the same way a real
## gust of wind arrives.

const BASE_LEVEL := 0.5     ## the idle multiplier between gusts — never fully still
const PEAK := 1.8           ## the multiplier at a gust's strongest moment
const GUST_PERIOD := 7.0    ## seconds between gust peaks, at a fixed world X
const GUST_SHARPNESS := 6.0 ## higher = a shorter, punchier bump with more calm in between
const TRAVEL_SPEED := 6.0   ## world units/sec the gust front sweeps along X

## Returns a multiplier (BASE_LEVEL..PEAK) for whatever a caller wants to
## scale by wind right now — foliage sway amount, ambient-mote turbulence,
## anything else that should visibly gust. `world_xz` only needs .x for the
## travel offset; .y (really world Z) is unused today but kept for callers
## that already have a Vector2(world.x, world.z) handy, and in case a future
## tweak wants the front to travel diagonally instead of straight along X.
static func sample(world_xz: Vector2, time: float) -> float:
	var local_time := time - world_xz.x / TRAVEL_SPEED
	var phase := fposmod(local_time, GUST_PERIOD) / GUST_PERIOD   # 0..1, wraps every GUST_PERIOD
	var bump := pow(maxf(sin(phase * PI), 0.0), GUST_SHARPNESS)
	return BASE_LEVEL + bump * (PEAK - BASE_LEVEL)
