class_name LevelEnvironment
extends Node
## Drop one of these into a level scene and give it an EnvironmentConfig to
## give that level its own color grade / lighting (see world/well_lighting.tres).
## Main picks it up when the level loads (_apply_level_lighting()) and uses it
## instead of the outdoor or interior default, and can switch a reverb on. Levels without one are unchanged.
## Whether the sky/sun are forced off is still decided by the level's
## "interior_level" group, not by this config.

@export var config: EnvironmentConfig

@export_group("Reverb")
## Echo on all the game's audio while this level is loaded (caves, wells...).
@export var reverb_enabled := false
@export_range(0.0, 1.0, 0.01) var reverb_room_size := 0.8   ## bigger = longer tail
@export_range(0.0, 1.0, 0.01) var reverb_damping := 0.5     ## higher = duller, faster-fading echoes
@export_range(0.0, 1.0, 0.01) var reverb_wet := 0.3         ## how much echo is mixed in
@export_range(20.0, 500.0, 1.0) var reverb_predelay_msec := 60.0   ## gap before the first echo — higher reads as a bigger space
