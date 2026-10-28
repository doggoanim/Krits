class_name SplashFx
extends RefCounted
## A little splash where a slime ball hits: droplets flung back and out in
## the ball's colour, falling with gravity, plus a quick expanding splat.
## Fire and forget: SplashFx.spawn(parent, position, color, direction).

const DROPS := 12
const GRAVITY := 14.0
const DROP_TIME := 0.5

static func spawn(parent: Node, pos: Vector3, color: Color, hit_dir := Vector3.ZERO) -> void:
	if parent == null:
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.radial_segments = 8
	mesh.rings = 4
	var back := -hit_dir.normalized() if hit_dir.length_squared() > 0.001 else Vector3.UP
	for i in DROPS:
		var drop := MeshInstance3D.new()
		drop.mesh = mesh
		drop.material_override = mat
		root.add_child(drop)
		var scatter := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1))
		var vel := (back * 2.0 + scatter * 2.2) * randf_range(0.7, 1.3)
		var size := randf_range(0.6, 1.5)
		drop.scale = Vector3.ONE * size
		var tw := drop.create_tween()
		tw.set_parallel(true)
		tw.tween_method(func(t: float) -> void:
			drop.position = vel * t + Vector3.DOWN * (0.5 * GRAVITY * t * t), 0.0, DROP_TIME, DROP_TIME)
		tw.tween_property(drop, "scale", Vector3.ZERO, DROP_TIME * 0.4).set_delay(DROP_TIME * 0.6)
	# Splat: a flat blob that bursts open and fades.
	var splat := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 0.4
	disc.height = 0.8
	splat.mesh = disc
	var splat_mat := StandardMaterial3D.new()
	splat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splat_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splat_mat.albedo_color = Color(color, 0.8)
	splat.material_override = splat_mat
	root.add_child(splat)
	splat.scale = Vector3.ONE * 0.3
	var st := splat.create_tween().set_parallel(true)
	st.tween_property(splat, "scale", Vector3(1.6, 0.5, 1.6), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_property(splat_mat, "albedo_color:a", 0.0, 0.25).set_delay(0.08)
	root.get_tree().create_timer(DROP_TIME + 0.1).timeout.connect(root.queue_free)
