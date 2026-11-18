class_name ScheduleStop
extends Resource
## One entry of an NPC's daily routine (see NpcSchedule): from `from_hour` on, the NPC is
## doing `mode` at `place` until the next entry starts.

enum Mode {
	STAND,    ## stands at `place`, now and then glancing around
	WANDER,   ## strolls about within `wander_radius` of `place`, pausing here and there
	INSIDE,   ## walks to `place` (a door) and goes indoors; out of sight and not talkable
}

@export_range(0.0, 24.0, 0.25) var from_hour := 8.0
@export var mode := Mode.STAND
## What the NPC does while standing about at this stop (needs the matching clip on the NPC).
@export var rest_pose := NPC.Pose.IDLE
## Where, as a path from the scene root to a Node3D (a Marker3D, or a door's spawn point).
## Empty = where the NPC was placed in the scene.
@export var place: NodePath
@export var wander_radius := 3.0
