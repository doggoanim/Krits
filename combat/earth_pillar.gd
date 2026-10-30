class_name EarthPillar
extends Node3D
## The Earth spell's second cast: a spike of rock bursting up out of the
## ground under an enemy. A tapered cone with a ring of random chunks around
## its base (same earth color as the rock armor), shoots up fast, holds a
## beat, then sinks back and frees itself. Purely visual — Arena deals the
## damage (see Arena._earth_pillars()).

const RISE_TIME := 0.14
const HOLD_TIME := 0.5
const SINK_TIME := 0.3
const CHUNKS := 7

## Spawns one pillar at `ground_pos` (the floor under the target). `height`
## and `width` are in metres.
static func spawn(parent: Node, ground_pos: Vector3, height: float, width: float) -> EarthPillar:
	var p := EarthPillar.new()
	parent.add_child(p)
	p.global_position = ground_pos
	p._build(height, width)
	p._animate()
	return p

func _build(height: float, width: float) -> void:
	var color: Color = Orb.KIND_COLORS[Orb.Kind.EARTH][0]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	var spike := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = width * 0.08
	cone.bottom_radius = width * 0.5
	cone.height = height
	cone.radial_segments = 6
	spike.mesh = cone
	spike.material_override = mat
	spike.position.y = height * 0.5
	spike.rotation.y = randf() * TAU
	add_child(spike)
	for i in CHUNKS:
		var chunk := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := width * randf_range(0.18, 0.34)
		box.size = Vector3(s, s * randf_range(0.8, 1.6), s)
		chunk.mesh = box
		chunk.material_override = mat
		var ang := TAU * float(i) / CHUNKS + randf_range(-0.3, 0.3)
		var r := width * randf_range(0.5, 0.8)
		chunk.position = Vector3(cos(ang) * r, box.size.y * 0.4, sin(ang) * r)
		chunk.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_child(chunk)

func _animate() -> void:
	scale = Vector3(1.0, 0.05, 1.0)
	var t := create_tween()
	t.tween_property(self, "scale:y", 1.0, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(HOLD_TIME)
	t.tween_property(self, "scale", Vector3(1.0, 0.02, 1.0), SINK_TIME).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
