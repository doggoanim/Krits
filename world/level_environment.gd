class_name LevelEnvironment
extends Node
## Drop one of these into a level scene and give it an EnvironmentConfig to
## give that level its own color grade / lighting (see world/well_lighting.tres).
## Main picks it up when the level loads (_apply_level_lighting()) and uses it
## instead of the outdoor or interior default. Levels without one are unchanged.
## Whether the sky/sun are forced off is still decided by the level's
## "interior_level" group, not by this config.

@export var config: EnvironmentConfig
