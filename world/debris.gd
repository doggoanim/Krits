class_name Debris
extends RefCounted
## Physical rubble for things that break (Smashable): a burst of small rigid pieces that fly
## out of the break, tumble, bounce off the world, settle, then shrink away. Planks and splinters
## for wood, curved shards for pottery. Pieces live on the loose-prop physics layer, so they
## collide with the world but never with the player, and a global cap keeps a smashing spree cheap.

const LOOSE_LAYER := 1 << 7
const WORLD_LAYER := 1
const MAX_PIECES := 90                ## alive at once, across everything
const LIFETIME := Vector2(2.6, 4.2)   ## seconds before a piece starts to shrink
const SHRINK_TIME := 0.7
const MIN_PIECES := 7
const MAX_NEW := 18

static var _alive := 0

## Bursts `bounds` (a world-space box around what broke) into pieces of `color`. `push` is the
## direction of the hit (a dive sends the pieces onward, a pound sends them up and out).
static func burst(host: Node, bounds: AABB, color: Color, wooden: bool, push: Vector3) -> void:
	if host == null or not host.is_inside_tree():
		return
	var root := host.get_tree().current_scene
	var size := bounds.size
	var n := clampi(roundi(pow(maxf(size.x * size.y * size.z, 0.01), 1.0 / 3.0) * 18.0), MIN_PIECES, MAX_NEW)
	n = mini(n, MAX_PIECES - _alive)
	var center := bounds.get_center()
	for i in n:
		var at := center + Vector3(randf_range(-0.5, 0.5) * size.x, randf_range(-0.4, 0.5) * size.y, randf_range(-0.5, 0.5) * size.z)
		var out := (at - center)
		out.y = maxf(out.y, 0.0) + 0.25
		var vel := out.normalized() * randf_range(1.2, 3.0) + push * randf_range(1.0, 2.6) + Vector3.UP * randf_range(1.2, 2.8)
		_piece(root, at, color, wooden, vel, size)

static func _piece(root: Node, at: Vector3, color: Color, wooden: bool, vel: Vector3, source: Vector3) -> void:
	var scale_ref := clampf(maxf(source.x, source.z), 0.35, 1.2)
	var dims: Vector3
	if wooden:   # planks and splinters
		dims = Vector3(randf_range(0.04, 0.09), randf_range(0.025, 0.05), randf_range(0.15, 0.4)) * scale_ref * 1.4
	else:        # flat shards
		dims = Vector3(randf_range(0.07, 0.15), randf_range(0.02, 0.04), randf_range(0.07, 0.15)) * scale_ref * 1.6
	var body := RigidBody3D.new()
	body.collision_layer = LOOSE_LAYER
	body.collision_mask = WORLD_LAYER
	body.mass = 0.25 + dims.x * dims.z * 4.0
	body.continuous_cd = true
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.3 if wooden else 0.15
	mat.friction = 0.85
	body.physics_material_override = mat
	body.linear_damp = 0.15
	body.angular_damp = 0.6
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dims
	shape.shape = box
	body.add_child(shape)
	var mesh := BoxMesh.new()
	mesh.size = dims
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var tint := color.lightened(randf_range(-0.12, 0.15))
	mi.material_override = HouseParts.toon(tint)
	body.add_child(mi)
	root.add_child(body)
	body.global_position = at
	body.global_rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	body.linear_velocity = vel
	body.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	_alive += 1
	body.tree_exited.connect(func() -> void: _alive -= 1)
	var tween := body.create_tween()
	tween.tween_interval(randf_range(LIFETIME.x, LIFETIME.y))
	tween.tween_property(mi, "scale", Vector3.ZERO, SHRINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(body.queue_free)
