class_name CaveGlimmers
extends Node3D
## Tiny motes of cyan light drifting around each crystal in the well, like cave insects or
## dust catching the glow. Built in code from the crystal lights (no art): a few emissive
## specks per crystal that circle and bob, held in stepped poses (see Choppy). Crystals
## far from the player are skipped.

@export var lights_path: NodePath = ^"../AccentLights"
@export var crystal_prefix := "CyanCrystal"
@export var per_crystal := 3
@export var orbit_radius := Vector2(0.5, 1.3)
@export var orbit_height := Vector2(0.2, 1.4)
@export var orbit_speed := Vector2(0.25, 0.7)   ## rad/s, sign randomised per mote
@export var mote_size := 0.035
@export var color := Color(0.55, 1.0, 1.0)
@export var active_distance := 28.0

class Mote:
	var mesh: MeshInstance3D
	var centre: Node3D
	var radius := 1.0
	var height := 0.5
	var speed := 0.4
	var phase := 0.0

var _motes: Array[Mote] = []
var _last_step := -1

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	var holder := get_node_or_null(lights_path)
	if holder == null:
		set_process(false)
		return
	var mesh := SphereMesh.new()
	mesh.radius = mote_size
	mesh.height = mote_size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	for child in holder.get_children():
		if not (child is OmniLight3D and String(child.name).begins_with(crystal_prefix)):
			continue
		for i in per_crystal:
			var m := Mote.new()
			m.centre = child
			m.radius = randf_range(orbit_radius.x, orbit_radius.y)
			m.height = randf_range(orbit_height.x, orbit_height.y)
			m.speed = randf_range(orbit_speed.x, orbit_speed.y) * (1.0 if randf() < 0.5 else -1.0)
			m.phase = randf() * TAU
			m.mesh = MeshInstance3D.new()
			m.mesh.mesh = mesh
			m.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m.mesh)
			_motes.append(m)

func _process(_delta: float) -> void:
	var step := Choppy.index()
	if step == _last_step:
		return
	_last_step = step
	var t := Choppy.time()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	for m in _motes:
		var near := player == null or player.global_position.distance_to(m.centre.global_position) < active_distance
		m.mesh.visible = near
		if not near:
			continue
		var a := m.phase + t * m.speed
		var up := m.height + sin(t * 1.3 + m.phase * 2.0) * 0.12
		m.mesh.global_position = m.centre.global_position + Vector3(cos(a) * m.radius, up, sin(a) * m.radius)
