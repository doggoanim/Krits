class_name GlowCrystal
extends Node3D
## A small cluster of glowing crystals — gives a light a visible source.
## Add as a CHILD of an OmniLight3D: it builds a few leaning, pointed prisms
## with an emissive material tinted to the light's colour, and (optionally)
## settles onto the floor below, carrying the light up with it so the light
## ends up just above the crystals instead of floating or buried.

@export var crystal_count := 4
@export var height := Vector2(0.35, 0.75)
@export var radius := 0.09
@export var lean_degrees := 22.0
@export var spread := 0.22                   ## how far apart the prisms stand
@export var emission_energy := 2.5
@export var snap_to_ground := true
@export var light_lift := 0.7                ## how far above the floor the light sits after snapping
@export var search_up := 1.5
@export var search_down := 8.0
@export_flags_3d_physics var ground_mask := 1

func _ready() -> void:
	_build()
	if snap_to_ground:
		await get_tree().physics_frame
		await get_tree().physics_frame
		_snap()

func _colour() -> Color:
	var parent := get_parent() as Light3D
	return parent.light_color if parent != null else Color(0.4, 0.9, 1.0)

func _build() -> void:
	var c := _colour()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c.darkened(0.35)
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = emission_energy
	mat.roughness = 0.3
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position) if is_inside_tree() else 1
	for i in crystal_count:
		var h := rng.randf_range(height.x, height.y)
		var prism := CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = radius * rng.randf_range(0.8, 1.3)
		prism.height = h
		prism.radial_segments = 5
		prism.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = prism
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf() * TAU
		mi.position = Vector3(cos(a), 0.0, sin(a)) * spread * rng.randf() + Vector3.UP * h * 0.5
		mi.rotation = Vector3(
			deg_to_rad(rng.randf_range(-lean_degrees, lean_degrees)), rng.randf() * TAU,
			deg_to_rad(rng.randf_range(-lean_degrees, lean_degrees)))
		add_child(mi)

func _snap() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * search_up
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (search_up + search_down), ground_mask))
	if hit.is_empty():
		return
	var light := get_parent() as Node3D
	if light != null:
		light.global_position = hit.position + Vector3.UP * light_lift
	global_position = hit.position
