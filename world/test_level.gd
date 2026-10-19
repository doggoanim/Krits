class_name TestLevel
extends Node3D
## Blockout level for trying the mechanics: ground, walls to bounce off, platforms,
## three spawnpoints and a few encounter zones (two of them close together).

func _ready() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(160, 1, 160), Color(0.35, 0.5, 0.35))
	# Wall-bounce practice: tall walls
	_box(Vector3(-10, 6, -12), Vector3(1, 12, 10), Color(0.6, 0.6, 0.65))
	_box(Vector3(-4, 6, -12), Vector3(1, 12, 10), Color(0.6, 0.6, 0.65))
	# Platforms / stairs
	for i in 3:
		var h := 1.5 * (i + 1)
		_box(Vector3(14 + i * 4, h * 0.5, 6), Vector3(4, h, 4), Color(0.55, 0.45, 0.35))
	_box(Vector3(30, 4, 6), Vector3(8, 1, 8), Color(0.7, 0.6, 0.4))
	# Long-jump gap
	_box(Vector3(0, 0.5, 20), Vector3(8, 1, 8), Color(0.5, 0.5, 0.7))
	_box(Vector3(0, 0.5, 40), Vector3(8, 1, 8), Color(0.5, 0.5, 0.7))
	_box(Vector3(0, 0.0, 30), Vector3(10, 0.2, 14), Color(0.8, 0.2, 0.2))   # lava-colored pit marker

	_spawn(&"start", "Hometown", Vector3(0, 0, 0), &"")
	_spawn(&"hill", "Hill Outpost", Vector3(30, 4.5, 6), &"azure")
	_spawn(&"far", "Far Platform", Vector3(0, 1.0, 40), &"crimson")

	# Overworld enemies: they pop in when you approach and wander. Touch one to fight.
	_enemy(&"slime_solo", Vector3(-25, 0.2, 10), EnemyLibrary.green_slime())
	_enemy(&"piercer_solo", Vector3(-30, 0.2, -30), EnemyLibrary.piercer())
	# Two close together merge into one bigger fight, three even bigger.
	_enemy(&"pair_a", Vector3(25, 0.2, -25), EnemyLibrary.spinner())
	_enemy(&"pair_b", Vector3(31, 0.2, -25), EnemyLibrary.green_slime())
	_enemy(&"pack_a", Vector3(-5, 0.2, -50), EnemyLibrary.green_slime())
	_enemy(&"pack_b", Vector3(0, 0.2, -52), EnemyLibrary.spinner())
	_enemy(&"pack_c", Vector3(5, 0.2, -50), EnemyLibrary.piercer())

func _box(pos: Vector3, size: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	body.add_child(mi)
	add_child(body)

func _spawn(id: StringName, nm: String, pos: Vector3, outfit: StringName) -> void:
	var sp := Spawnpoint.new()
	sp.spawn_id = id
	sp.display_name = nm
	sp.unlocks_outfit = outfit
	sp.position = pos
	add_child(sp)

func _enemy(id: StringName, pos: Vector3, data: EnemyData) -> void:
	var e := WorldEnemy.new()
	e.enemy_id = id
	e.data = data
	e.position = pos
	add_child(e)
