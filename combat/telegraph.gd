class_name Telegraph
extends Node3D
## Hand-drawn warning shapes for enemy attacks, in the arena's chalk look:
##   Telegraph.exclaim(enemy, height)   a bouncing "!" over the attacker
##   Telegraph.circle(parent, radius)   a landing zone that fills up as the
##                                      attack winds up (leap)
##   Telegraph.line(parent, width)      an aim line from attacker to target
##                                      (burst shot)
## Create one, move/update it each frame while the attack winds up, call
## lock() when the attack commits and fade_out() once it is over.

const WARN_COLOR := Color(1.0, 0.35, 0.3)
const FLOOR_LIFT := 0.08

var _fill: MeshInstance3D
var _parts: Array[MeshInstance3D] = []
var _tween: Tween

## A "!" that pops above `enemy` and frees itself.
static func exclaim(enemy: Node3D, height: float) -> void:
	var label := Label3D.new()
	label.text = "!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.pixel_size = 0.008
	label.font_size = 96
	label.outline_size = 24
	label.modulate = Color(1.0, 0.85, 0.25)
	label.outline_modulate = Color(0, 0, 0)
	label.render_priority = 12
	label.outline_render_priority = 11
	label.position = Vector3(0, height, 0)
	enemy.add_child(label)
	label.scale = Vector3.ONE * 0.2
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector3.ONE * 1.3, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector3.ONE, 0.1)
	tw.tween_property(label, "position:y", height + 0.25, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(label, "modulate:a", 0.0, 0.2)
	tw.tween_callback(label.queue_free)

## A flat circle `radius` wide. Position it with global_position; grow its
## fill with set_fill(0..1).
static func circle(parent: Node, radius: float) -> Telegraph:
	var t := Telegraph.new()
	parent.add_child(t)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 32
	disc.rings = 1
	t._add_part(disc, Color(WARN_COLOR, 0.28), 0)
	var fill_mesh := CylinderMesh.new()
	fill_mesh.top_radius = radius
	fill_mesh.bottom_radius = radius
	fill_mesh.height = 0.02
	fill_mesh.radial_segments = 32
	fill_mesh.rings = 1
	t._fill = t._add_part(fill_mesh, Color(WARN_COLOR, 0.55), 1)
	t._fill.scale = Vector3(0.01, 1.0, 0.01)
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(radius - 0.12, 0.05)
	ring.outer_radius = radius
	ring.rings = 32
	ring.ring_segments = 4
	var ring_part := t._add_part(ring, Color(1, 1, 1, 0.9), 2)
	ring_part.scale = Vector3(1.0, 0.1, 1.0)
	return t

## A flat strip of `width`; aim it with set_line().
static func line(parent: Node, width: float) -> Telegraph:
	var t := Telegraph.new()
	parent.add_child(t)
	var strip := BoxMesh.new()
	strip.size = Vector3(width, 0.02, 1.0)   # z is stretched to the line's length
	t._add_part(strip, Color(WARN_COLOR, 0.4), 0)
	return t

func set_fill(amount: float) -> void:
	if _fill:
		var s := clampf(amount, 0.01, 1.0)
		_fill.scale = Vector3(s, 1.0, s)

## Stretches the strip between two world points (kept just above the ground
## at `from`'s height).
func set_line(from: Vector3, to: Vector3) -> void:
	var flat := to - from
	flat.y = 0.0
	var length := maxf(flat.length(), 0.01)
	global_position = from + flat * 0.5
	rotation.y = atan2(flat.x, flat.z)
	for p in _parts:
		p.scale = Vector3(1.0, 1.0, length)

## The attack commits: flash white.
func lock() -> void:
	for p in _parts:
		var mat := p.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(1, 1, 1, 0.8)
	if _fill:
		set_fill(1.0)

func fade_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for p in _parts:
		var mat := p.material_override as StandardMaterial3D
		if mat:
			_tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	_tween.chain().tween_callback(queue_free)

func _add_part(mesh: Mesh, color: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.render_priority = priority
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_parts.append(mi)
	return mi
