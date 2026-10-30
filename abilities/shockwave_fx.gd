class_name ShockwaveFx
extends Node3D
## The Shockwave ability's visuals: a flat energy ring that sweeps out across
## the ground to the ability's full reach, a filled pulse behind it, a quick
## dome flash over the caster, and dust kicked up where the ring ends. Fire
## and forget — ShockwaveFx.spawn(parent, feet_position, radius, color) frees
## itself. Purely visual; AbilityRunner deals the damage.

const SPREAD_TIME := 0.4
const FADE_TIME := 0.25
const DUST_PUFFS := 14

static func spawn(parent: Node3D, feet: Vector3, radius: float, color: Color) -> void:
	var fx := ShockwaveFx.new()
	parent.add_child(fx)
	fx.global_position = feet + Vector3.UP * 0.08
	fx._play(radius, color)

func _play(radius: float, color: Color) -> void:
	var ring := _ring_mesh(color)
	var pulse := _disc_mesh(color)
	var dome := _dome_mesh(color)
	add_child(pulse)
	add_child(ring)
	add_child(dome)

	for node: MeshInstance3D in [ring, pulse]:
		node.scale = Vector3(0.1, 1.0, 0.1)
	dome.scale = Vector3.ONE * 0.5

	var t := create_tween().set_parallel(true)
	var spread := func(node: MeshInstance3D, alpha_from: float) -> void:
		t.tween_property(node, "scale", Vector3(radius, 1.0, radius), SPREAD_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var mat := node.material_override as StandardMaterial3D
		mat.albedo_color.a = alpha_from
		t.tween_property(mat, "albedo_color:a", 0.0, SPREAD_TIME + FADE_TIME)
	spread.call(ring, 0.95)
	spread.call(pulse, 0.35)
	t.tween_property(dome, "scale", Vector3.ONE * radius * 0.35, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(dome.material_override, "albedo_color:a", 0.0, 0.3).from(0.5)

	# Dust where the front lands, once the ring has nearly arrived.
	get_tree().create_timer(SPREAD_TIME * 0.7).timeout.connect(func() -> void:
		for i in DUST_PUFFS:
			var ang := TAU * float(i) / DUST_PUFFS + randf_range(-0.15, 0.15)
			VFX.smoke_puff(self, global_position + Vector3(cos(ang), 0.0, sin(ang)) * radius * 0.9, 1.0))
	get_tree().create_timer(SPREAD_TIME + FADE_TIME + 1.2).timeout.connect(queue_free)

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	return m

func _ring_mesh(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 8
	mi.mesh = torus
	mi.material_override = _material(color.lightened(0.35))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _disc_mesh(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 48
	mi.mesh = disc
	mi.material_override = _material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _dome_mesh(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.is_hemisphere = true
	mi.mesh = sphere
	mi.material_override = _material(color.lightened(0.2))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
