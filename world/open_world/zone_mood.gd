class_name ZoneMood
extends Resource
## The distance-haze look of one region of the open world. ZoneStreamer blends
## between the moods of the zones the player is near, so walking from one
## region into the next never pops.

@export var haze_color := Color(0.78, 0.88, 0.96)
@export var haze_density := 0.006
