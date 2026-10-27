class_name InteriorRoom
extends Node3D
## A simple enclosed building interior — floor, walls and ceiling built as
## one box, same as TestLevel's own blockout style, except this one is
## deliberately "inside-out": its material's cull_mode is flipped
## (CULL_FRONT instead of the default CULL_BACK) so the faces render from
## their INNER side instead of their outer one. Standing inside it (the only
## place a player is ever meant to be relative to this mesh) you see the
## walls/ceiling around you like a normal room; looked at from outside,
## there's nothing to see at all — which is exactly the point, since nothing
## outside this box should ever be visible from in here either. The box's
## collider doesn't care which way its faces are drawn, so it's built the
## ordinary way round and simply keeps the player inside.
##
## Its own back wall carries a Door leading back out (`exit_level`), with a
## DoorSpawn just inside it for the next time the player walks back in
## through the matching Door elsewhere. Not meant to stay a single fixed
## layout forever — duplicate this scene per distinct interior (a shop, a
## house, a cave) and swap in real wall/furniture assets later, same
## blockout-first spirit as TestLevel.

@export var room_size := Vector3(10.0, 4.0, 10.0)
@export var wall_color := Color(0.78, 0.7, 0.58)
@export var light_color := Color(1.0, 0.9, 0.75)

@export_group("Return Door")
## The outdoor (or other) level this room's door leads back to — a PATH, not
## a PackedScene export. See Door.target_level's own doc comment: this room's
## return door normally points right back at the very level that placed the
## entrance Door leading in here, so the two .tscn files reference each
## other, and a PackedScene export would bake that into a real circular
## ext_resource dependency (Godot can deadlock loading either one). Passed
## straight through to the Door built below, which loads it lazily instead.
@export_file("*.tscn") var exit_level: String = "res://world/hometown.tscn"
@export var exit_spawn_id: StringName = &"start"   ## Spawnpoint/DoorSpawn id in exit_level to arrive at

func _ready() -> void:
	_room_shell()
	_lamp()
	_back_door()

## See the class doc comment for why cull_mode is flipped. Tagged with
## CameraRig.GROUND_LAYER on top of the regular "world" layer — not just
## because the floor is walkable (TestLevel's own _box() convention), but so
## the camera's own spring-arm is pushed in by the walls/ceiling too. Without
## that, the camera could clip straight through them in a room this small,
## which would show the empty sky behind it — exactly the "seeing outside"
## this whole feature exists to prevent.
func _room_shell() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | CameraRig.GROUND_LAYER
	add_child(body)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = room_size
	cs.shape = shape
	cs.position.y = room_size.y * 0.5
	body.add_child(cs)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = room_size
	mi.mesh = bm
	mi.position.y = room_size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = wall_color
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mi.material_override = mat
	body.add_child(mi)

## A single warm point light standing in for whatever lamps/windows a real
## interior will eventually have — the outdoor sun's own DirectionalLight3D
## barely reaches in here (it's blocked by the ceiling from above, same as
## real sunlight would be) and the flat ambient (see main.gd's
## _build_environment()) alone reads as flat and lifeless for an enclosed
## space this size.
func _lamp() -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, room_size.y - 0.6, 0)
	light.light_color = light_color
	light.light_energy = 1.4
	light.omni_range = maxf(room_size.x, room_size.z) * 0.9
	add_child(light)

## The door back out, plus the spot just inside it the player lands on when
## they come back in (see DoorSpawn). Both sit against the room's own back
## wall (+Z, same convention as the box's size being centered on this node).
func _back_door() -> void:
	var wall_z := room_size.z * 0.5

	var spawn := DoorSpawn.new()
	spawn.spawn_id = &"enter"
	spawn.position = Vector3(0, 0, wall_z - 1.4)   # a step into the room, facing the door
	add_child(spawn)

	var door := Door.new()
	door.target_level = exit_level
	door.target_spawn_id = exit_spawn_id
	door.prompt_text = "Press E to exit"
	door.position = Vector3(0, 0, wall_z - 0.2)
	add_child(door)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 2.2, 0.3)
	cs.shape = shape
	cs.position.y = 1.1
	door.add_child(cs)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 2.2, 0.2)
	mesh.mesh = bm
	mesh.position.y = 1.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.22, 0.12)
	mesh.material_override = mat
	door.add_child(mesh)
