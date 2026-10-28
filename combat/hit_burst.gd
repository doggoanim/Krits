class_name HitBurst
extends Node3D
## Cartoony impact pop at a point in the world: a chunky damage number that
## bounces up and fades, plus a ring of round confetti flung outward.
## Fire and forget — HitBurst.spawn(parent, position, damage); it frees itself.

const SHARD_COUNT := 10
const SHARD_COLORS := [Color(1, 1, 1), Color(1, 0.9, 0.4)]
const LIFETIME := 0.8
const BONUS_COLORS := [Color(1.0, 0.85, 0.2), Color(1.0, 0.6, 0.15)]

var _bonus := false

## `bonus` = the ground-pound bonus landed: golden, bigger, with a "!".
static func spawn(parent: Node, world_pos: Vector3, damage: float, power := 1.0, bonus := false) -> void:
	var burst := HitBurst.new()
	parent.add_child(burst)
	burst.global_position = world_pos
	burst._bonus = bonus
	burst._play(damage, power * (1.6 if bonus else 1.0))

func _play(damage: float, power: float) -> void:
	_add_number(damage, power)
	_add_shards(power)
	get_tree().create_timer(LIFETIME + 0.1).timeout.connect(queue_free)

func _add_number(damage: float, power: float) -> void:
	var label := Label3D.new()
	var whole := is_equal_approx(damage, roundf(damage))
	label.text = ("%d" if whole else "%.1f") % damage
	if _bonus:
		label.text += "!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.pixel_size = 0.005
	label.font_size = 96
	label.outline_size = 28
	label.modulate = Color(1.0, 0.7, 0.15) if _bonus else Color(1, 0.93, 0.45)
	label.outline_modulate = Color(0, 0, 0)
	label.render_priority = 12
	label.outline_render_priority = 11
	add_child(label)
	label.scale = Vector3.ONE * 0.2
	var s := 1.0 + 0.12 * minf(power, 6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "scale", Vector3.ONE * s, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", 1.3, LIFETIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(LIFETIME - 0.25)
	tw.tween_property(label, "outline_modulate:a", 0.0, 0.25).set_delay(LIFETIME - 0.25)

func _add_shards(power: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.radial_segments = 8
	mesh.rings = 4
	var count := SHARD_COUNT + int(minf(power, 6.0)) * 2
	for i in count:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.albedo_color = (BONUS_COLORS if _bonus else SHARD_COLORS)[i % 2]
		var shard := MeshInstance3D.new()
		shard.mesh = mesh
		shard.material_override = mat
		add_child(shard)
		var angle := TAU * float(i) / count + randf() * 0.4
		var dir := Vector3(cos(angle), randf_range(0.2, 0.9), sin(angle)).normalized()
		var dist := randf_range(1.0, 1.7) * (1.0 + 0.05 * minf(power, 6.0))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(shard, "position", dir * dist, 0.4) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(shard, "scale", Vector3.ZERO, 0.4).set_delay(0.12)
