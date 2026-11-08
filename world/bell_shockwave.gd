class_name BellShockwave
extends Node3D
## A glowing ring-shell that bursts outward from where the bell rang and fades
## away, so the player can see which way to go. Two shells, the second a beat
## behind. Drawn without depth testing so it reads from anywhere in town, even
## behind houses. Frees itself when done. Spawned by BellCall.

const SHADER := preload("res://world/bell_shockwave.gdshader")
const DURATION := 2.4
const MAX_RADIUS := 90.0
const COLOR := Color(1.0, 0.86, 0.45)
const SHELL_DELAY := 0.35

func _ready() -> void:
	for i in 2:
		_spawn_shell(i * SHELL_DELAY)
	get_tree().create_timer(DURATION + SHELL_DELAY + 0.1).timeout.connect(queue_free)

func _spawn_shell(delay: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"tint", COLOR)
	mat.set_shader_parameter(&"fade", 1.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.01
	mi.extra_cull_margin = 4096.0
	add_child(mi)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3.ONE * MAX_RADIUS, DURATION).set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"fade", v), 1.0, 0.0, DURATION) \
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
