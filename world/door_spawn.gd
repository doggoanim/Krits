class_name DoorSpawn
extends Node3D
## Where the player appears after walking through a Door into this level —
## the interior-level equivalent of Spawnpoint (world/spawnpoint.gd), but
## deliberately lighter: no fast-travel unlock, no heal, no visible marker,
## and not a member of the "spawnpoints" group TravelMenu reads from. Every
## building interior gets its own arrival spot right inside its door; it
## would be strange for that to also double as a healing fast-travel pin
## the player can beam into from the Travel Menu.
##
## Put one just inside each door a Door's `target_spawn_id` can point at —
## see Main._find_spawn_in(), which looks for either this or a real
## Spawnpoint, scoped to whichever level was just loaded.

@export var spawn_id: StringName = &"start"

func respawn_position() -> Vector3:
	return global_position
