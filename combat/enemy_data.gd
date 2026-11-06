class_name EnemyData
extends Resource
## Data-driven enemy definition. Make new enemies by creating new instances/.tres files.

@export var id: StringName = &"grunt"
@export var display_name := "Grunt"
@export var max_hp := 60.0
@export var gold := 0   ## unused: enemies no longer pay gold — sell their drops at a shop instead
@export var move_speed := 3.5
## Used for the placeholder sphere when no model is set, and also as the
## accent color for this enemy's slime trail / special-attack projectiles
## when those are enabled below (so one field covers both looks).
@export var color := Color(0.8, 0.2, 0.2)
@export var size := 1.0
@export var patterns: Array[BulletPattern] = []
@export var drops: Array[ItemDrop] = []   ## rolled when this enemy is defeated; collected when the fight is won

## Optional animated model (see EnemyVisual). Leave unset to keep the plain
## procedural sphere — existing enemies (Spinner, Piercer, ...) don't need
## any of this unless/until they get their own model.
@export_group("Model")
@export var model: PackedScene
@export var model_height := 1.4      ## target world-space height when a model is set
## Blender's glTF export doesn't always agree with Godot's -Z-forward
## convention, so an enemy can end up visually facing backward relative to
## its movement direction — same issue PlayerVisual had, same fix: a
## 180-degree turn. Set to 0.0 if a particular model's export already faces -Z.
@export var model_facing_offset := PI
@export var anim_idle: StringName = &"Idle"
@export var anim_move: StringName = &"Moving"
@export var anim_death: StringName = &"Death"

## A telegraphed pounce: holds anim_leap_ready for leap_ready_time, then arcs
## toward wherever the player was standing when the leap committed (not a
## homing target — it's meant to be dodgeable), tumbling as it travels, and
## lands in a damaging burst that also drops a (bigger) puddle if
## leaves_puddle_trail is on. Leave leap_max_cooldown at 0 (the default) to
## skip this attack entirely — most enemies don't have one.
@export_group("Leap Attack")
@export var leap_min_cooldown := 0.0
@export var leap_max_cooldown := 0.0
@export var leap_ready_time := 1.0
@export var leap_travel_time := 0.6    ## seconds spent airborne, regardless of distance
@export var leap_height := 3.0         ## arc apex above a straight line to the landing spot
@export var leap_damage := 14.0
@export var leap_radius := 2.0         ## landing impact radius that can hit the player
@export var anim_leap_ready: StringName = &""
@export var anim_leap: StringName = &""

func has_leap() -> bool:
	return leap_max_cooldown > 0.0

## A machine-gun-style volley: fires a randomized number of aimed shots
## (shoot_count_min..shoot_count_max), playing anim_shoot once per shot.
## Leave shoot_max_cooldown at 0 (the default) to skip this attack.
@export_group("Burst Shoot")
@export var shoot_min_cooldown := 0.0
@export var shoot_max_cooldown := 0.0
@export var shoot_count_min := 1
@export var shoot_count_max := 10
@export var shoot_ready_time := 0.6    ## telegraph ("!" + aim line) before the first shot
@export var shoot_interval := 0.12     ## minimum time between shots — Enemy stretches it to just outlast the player's i-frames
@export var shoot_speed := 10.0
@export var shoot_damage := 6.0
@export var shoot_rate_ramp := 1.5     ## each following shot comes this many times faster than the last (1 = steady)
@export var shoot_ball_radius := 0.28   ## size of each ball
@export_range(0.0, 1.0) var shoot_lead_falloff := 0.7   ## each following shot in a volley keeps this fraction of the previous shot's lead (1 = every shot predicts equally well)
@export_range(0.0, 1.0) var shoot_lead := 1.0   ## how much shots lead a moving player (0 = aim where they are now, 1 = full prediction)
@export var anim_shoot: StringName = &""

## Sounds (all optional). One of a list is picked at random each time.
@export_group("Sounds")
@export var sfx_footsteps: Array[AudioStream] = []
@export var sfx_leap: AudioStream
@export var sfx_land: AudioStream   ## when a leap touches down
@export var sfx_shoot: Array[AudioStream] = []

func has_burst_shoot() -> bool:
	return shoot_max_cooldown > 0.0

## Overworld behaviour (WorldEnemy): notice the player, pause on a "!", then
## chase until they get away. Touching still starts the fight as before — this
## only decides whether an enemy lets itself be walked past. The player walks at
## 8 m/s (PlayerConfig.walk_speed), so a chase_speed a little below that can be
## outrun, but not casually: stop, get cornered or take a detour and it catches up.
@export_group("Chase")
@export var chase_enabled := true
@export var detect_radius := 9.0        ## notices the player this close (needs a clear line of sight if line_of_sight)
@export var line_of_sight := true       ## walls between them block noticing (and keep it from losing you only briefly)
@export var alert_time := 0.6           ## stands on its "!" this long before running — the player's window to react
@export var chase_speed := 6.5          ## m/s while chasing
@export var give_up_radius := 18.0      ## player this far away: it gives up at once
@export var lose_time := 2.5            ## seconds out of range / out of sight before it gives up
@export var leash_radius := 24.0        ## never chases farther than this from its home
@export var chain_alert_radius := 8.0   ## idle friends this close join in when it notices (0 = lone wolf)
## The player is a jumpy, diving, long-jumping target, so a chaser is built to
## still be able to get them:
@export var contact_height := 3.0       ## touch zone is a tall cylinder this high, so hopping right over it still counts
@export var max_climb := 2.5            ## player this much higher than the enemy (on a ledge it can't climb to) counts as out of reach
@export var chase_ramp := 0.35          ## the longer it chases, the faster it gets: up to +35% ...
@export var chase_ramp_time := 4.0      ## ... after this many seconds (breaking line of sight resets it)

## Leaves a damaging, slowing, jump-disabling puddle (see SlimePuddle)
## wherever this enemy walks, plus a bigger one wherever a leap lands.
@export_group("Slime Trail")
@export var leaves_puddle_trail := false
@export var puddle_interval := 0.5     ## seconds between trail puddles while moving
@export var puddle_radius := 1.3
@export var puddle_lifetime := 5.0
@export var puddle_damage := 4.0
@export var puddle_tick_interval := 0.9
@export var puddle_landing_radius_mult := 1.6   ## leap-landing puddles are bigger than trail ones
