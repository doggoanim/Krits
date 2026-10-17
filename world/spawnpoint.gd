class_name Spawnpoint
extends Area3D
## Checkpoint + fast-travel node. Touch it once to unlock; it heals and saves.

@export var spawn_id: StringName = &"start"
@export var display_name := "Start"
@export var unlocks_outfit: StringName = &""   ## optional cosmetic reward

var _mat := StandardMaterial3D.new()

func _ready() -> void:
	add_to_group(&"spawnpoints")
	collision_layer = 1 << 5
	collision_mask = 1 << 1
	var s := CylinderShape3D.new()
	s.radius = 1.6
	s.height = 3.0
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position.y = 1.5
	add_child(cs)

	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 0.5
	c.height = 2.4
	m.mesh = c
	m.position.y = 1.2
	m.material_override = _mat
	add_child(m)
	var lbl := Label3D.new()
	lbl.text = display_name
	lbl.position.y = 3.0
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lbl)

	body_entered.connect(func(b: Node3D):
		if b is Player:
			activate())
	Events.spawnpoint_activated.connect(func(_id): _refresh())
	_refresh()

func is_unlocked() -> bool:
	return spawn_id in Game.unlocked_spawns

func activate() -> void:
	Game.unlock_spawn(spawn_id)
	Game.stats.full_heal()
	if unlocks_outfit != &"" and unlocks_outfit not in Game.unlocked_outfits:
		Game.unlocked_outfits.append(unlocks_outfit)

func respawn_position() -> Vector3:
	return global_position + Vector3.UP * 0.2

func _refresh() -> void:
	_mat.albedo_color = Color(0.3, 1.0, 0.5) if is_unlocked() else Color(0.5, 0.5, 0.55)
