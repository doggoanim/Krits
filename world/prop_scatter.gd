class_name PropScatter
extends Node3D
## Scatters small decorative props (grass tufts, flowers, ...) across the ground
## around this node, so a level feels lived-in without hand-placing hundreds.
##
## Each try picks a random spot inside `area_size` (centred on this node), drops
## a ray down onto the world, and keeps the spot only if
##   - the thing it hit belongs to a node whose name contains `ground_name_filter`
##     (default "grass": so paths/dirt, rocks and cliffs are skipped),
##   - the ground there is gentle enough (`max_slope_deg`), and
##   - a small sphere just above the spot touches nothing, so nothing sprouts
##     through fences, walls, trees or rocks.
## Each kept spot gets a random scene from `scenes`, a random yaw and size, and
## (optionally) a FoliageWind child so it sways like the hand-placed ones.
##
## Results are deterministic for a given `seed_value`, so the layout is the same
## every run — change the seed to reshuffle. Runs once, a couple of physics
## frames after the level loads (the ground colliders must exist first).

@export var scenes: Array[PackedScene] = []
@export var count := 150
@export var area_size := Vector2(60.0, 60.0)
@export var seed_value := 1
@export var ground_name_filter := "grass"
@export_range(0.0, 80.0) var max_slope_deg := 25.0
@export var clearance_radius := 0.3        ## how much free space a prop needs around it
@export var scale_range := Vector2(0.8, 1.3)
@export var sway := true
@export var wind_strength := 0.05
@export_flags_3d_physics var ground_mask := 1   ## the "world" physics layer
@export var max_tries_per_prop := 6

func _ready() -> void:
	if scenes.is_empty():
		return
	# Static colliders are only queryable after the physics server has stepped.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_scatter()

func _scatter() -> void:
	var space := get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var probe := SphereShape3D.new()
	probe.radius = clearance_radius
	var min_normal_y := cos(deg_to_rad(max_slope_deg))
	var placed := 0
	var tries := 0
	var max_tries := count * max_tries_per_prop
	while placed < count and tries < max_tries:
		tries += 1
		var x := rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5)
		var z := rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)
		var from := global_position + Vector3(x, 60.0, z)
		var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 120.0, ground_mask)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not _is_ground(hit.collider as Node):
			continue
		var normal: Vector3 = hit.normal
		if normal.y < min_normal_y:
			continue
		var pos: Vector3 = hit.position
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = probe
		query.collision_mask = ground_mask
		query.transform = Transform3D(Basis(), pos + Vector3.UP * (clearance_radius + 0.25))
		if not space.intersect_shape(query, 1).is_empty():
			continue
		_place(scenes[rng.randi() % scenes.size()], pos, rng)
		placed += 1

func _is_ground(collider: Node) -> bool:
	if ground_name_filter.is_empty():
		return true
	var n := collider
	while n != null and n != get_parent():
		if String(n.name).containsn(ground_name_filter):
			return true
		n = n.get_parent()
	return false

func _place(scene: PackedScene, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var node := scene.instantiate() as Node3D
	if node == null:
		return
	add_child(node)
	node.global_position = pos
	node.rotation.y = rng.randf() * TAU
	node.scale = Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)
	if sway:
		var wind := FoliageWind.new()
		wind.wind_strength = wind_strength
		wind.react_to_gusts = false   # idle sway only: keeps hundreds of these cheap
		node.add_child(wind)
