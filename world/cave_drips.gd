class_name CaveDrips
extends Node3D
## Drops of water falling from the ceiling and splashing into small ripples on
## the floor, with a quiet "plink" — for damp caves and wells.
##
## At load it picks `spot_count` random floor points inside `area_size` (a box
## around this node, searched downward from this node's height) and gives each
## its own random timer; every time a timer fires, a drip falls from
## `fall_height` above that spot, then a ripple ring spreads and fades. Spots
## are kept only if there is free headroom above them (so drips don't land on
## the tops of walls). Cheap: a few tweened quads, no particle systems.
##
## Put the node at roughly ceiling height over the area; resize with area_size.

@export var area_size := Vector2(8.0, 8.0)
@export var search_height := 6.0           ## rays start this far above the node and go down
@export var spot_count := 5
@export var fall_height := 3.5
@export var interval := Vector2(2.0, 6.0)  ## seconds between drips at one spot
@export var headroom := 3.5
@export var drip_color := Color(0.6, 0.9, 1.0, 0.9)
@export var volume_db := -20.0
@export var sound: AudioStream
@export_flags_3d_physics var ground_mask := 1

var _spots: Array[Vector3] = []
var _ripple_tex: Texture2D
var _drip_tex: Texture2D

func _ready() -> void:
	_ripple_tex = SoftCircleTexture.make_ring(64)
	_drip_tex = SoftCircleTexture.make(16)
	if sound == null and ResourceLoader.exists("res://sounds/SFX/water_splash_1.wav"):
		sound = load("res://sounds/SFX/water_splash_1.wav")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_find_spots()
	for s in _spots:
		_run_spot(s)

func _find_spots() -> void:
	var space := get_world_3d().direct_space_state
	var tries := 0
	while _spots.size() < spot_count and tries < spot_count * 20:
		tries += 1
		var from := global_position + Vector3(
			randf_range(-area_size.x * 0.5, area_size.x * 0.5), search_height,
			randf_range(-area_size.y * 0.5, area_size.y * 0.5))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 60.0, ground_mask))
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		var pos: Vector3 = hit.position
		var up_ray := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.1, pos + Vector3.UP * headroom, ground_mask)
		if not space.intersect_ray(up_ray).is_empty():
			continue
		_spots.append(pos)

func _run_spot(pos: Vector3) -> void:
	await get_tree().create_timer(randf_range(0.0, interval.y)).timeout
	while is_inside_tree():
		_drip(pos)
		await get_tree().create_timer(randf_range(interval.x, interval.y)).timeout

func _drip(pos: Vector3) -> void:
	var drop := _make_quad(_drip_tex, Vector2(0.05, 0.14), drip_color)
	add_child(drop)
	drop.global_position = pos + Vector3.UP * fall_height
	var fall_time := sqrt(2.0 * fall_height / 9.8)
	var tw := create_tween()
	tw.tween_property(drop, "global_position:y", pos.y + 0.03, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		drop.queue_free()
		_splash(pos))

func _splash(pos: Vector3) -> void:
	var ring := _make_quad(_ripple_tex, Vector2.ONE, Color(drip_color, 0.7), false)
	add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.02
	ring.rotation_degrees.x = -90.0   # flat on the floor
	ring.scale = Vector3.ONE * 0.1
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 0.9, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "transparency", 1.0, 0.9)
	tw.chain().tween_callback(ring.queue_free)
	if sound != null:
		var p := AudioStreamPlayer3D.new()
		p.stream = sound
		p.volume_db = volume_db
		p.pitch_scale = randf_range(2.0, 2.6)   # a high plink rather than a big splash
		p.unit_size = 3.0
		p.max_distance = 18.0
		add_child(p)
		p.global_position = pos
		p.finished.connect(p.queue_free)
		p.play()

func _make_quad(tex: Texture2D, size: Vector2, color: Color, billboard := true) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = color
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
