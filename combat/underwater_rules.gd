class_name UnderwaterRules
extends RefCounted
## The one place that decides which "medium" a fight happens in. Everything
## that has to agree about water vs. land (EncounterManager picking who may
## start a fight, WorldEnemy deciding who it notices, Arena shaping the
## battlefield) asks here instead of re-deriving it, so the rules stay in sync:
##
##   * The medium is decided when a fight starts and never changes: a player
##     swimming (SwimState) fights fish; a player on land fights land enemies.
##   * Fish only notice / fight swimmers, land enemies only land players.
##   * Any depth will do: the arena squeezes into whatever water column there is
##     (see MIN_HEADROOM and Arena's underwater orb/fish heights).

const MIN_HEADROOM := 2.5        ## the submerged arena is at least this tall (seabed to ceiling), however shallow the water
const SEABED_PROBE := 80.0        ## how far down the seabed is searched for
const CEILING_GAP := 0.15         ## extra headroom (x STAND_HEIGHT) kept under the surface-jump threshold

## The water the player is swimming in right now, or null (on land / wading).
static func swim_water(player: Player) -> WaterVolume:
	if player == null or player.machine == null or player.machine.current_name != &"Swim":
		return null
	return player.current_water()

static func is_swimming(player: Player) -> bool:
	return swim_water(player) != null

## World Y of the solid ground (seabed) under `pos`, or -INF if there is none.
static func seabed_y(player: Player, pos: Vector3) -> float:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * SEABED_PROBE, 1)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else -INF

## World Y the swimmer's head may not pass during a fight: low enough that the
## swim state's "jump out at the surface" check can never trigger (see
## SwimState), so the fight stays fully submerged with no surface to escape to.
static func swim_ceiling_y(water: WaterVolume, player: Player, floor_y: float) -> float:
	var c := player.config
	var feet_max := water.surface_world_y() - (c.water_swim_depth_ratio + c.swim_surface_jump_margin + CEILING_GAP) * Player.STAND_HEIGHT
	return maxf(feet_max + Player.STAND_HEIGHT, floor_y + MIN_HEADROOM)
