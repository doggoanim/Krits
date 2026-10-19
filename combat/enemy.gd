class_name Enemy
extends Node3D
## Arena enemy: wanders inside the arena and fires its bullet patterns.
## It has no collision; it only takes damage through the arena's orb system.

signal defeated(enemy: Enemy)

var data: EnemyData
var hp := 1.0
var arena: Arena
var target: Node3D

var _timers: Array[float] = []
var _steps: Array[int] = []
var _dest := Vector3.ZERO
var _mesh: MeshInstance3D   ## placeholder sphere, only built when data.model is unset
var _mat := StandardMaterial3D.new()
var _visual: EnemyVisual    ## animated model, only built when data.model is set
var _label: Label3D
var _flash := 0.0
var _dying := false   ## true once defeated, so a lingering death animation isn't overridden
var armed := false   ## only shoots once the arena starts the fight

func setup(d: EnemyData, a: Arena, t: Node3D) -> void:
	data = d
	arena = a
	target = t
	hp = d.max_hp
	for p in d.patterns:
		_timers.append(randf_range(0.5, p.interval))   # desync groups
		_steps.append(0)

func _ready() -> void:
	var label_height: float
	if data.model:
		_visual = EnemyVisual.new()
		add_child(_visual)
		_visual.setup(data)
		label_height = data.model_height * 1.3
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.7 * data.size
		sm.height = 1.4 * data.size
		_mesh = MeshInstance3D.new()
		_mesh.mesh = sm
		_mat.albedo_color = data.color
		# Cel-shaded to match the character: hard light/shadow bands, no shiny highlight.
		_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_mesh.material_override = _mat
		add_child(_mesh)
		label_height = 1.4 * data.size
	_label = Label3D.new()
	_label.position.y = label_height
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	add_child(_label)
	_update_label()
	_dest = global_position

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_move(delta)
	_shoot(delta)
	if _mesh:
		if _flash > 0.0:
			_flash -= delta
			_mat.albedo_color = Color.WHITE
		else:
			_mat.albedo_color = data.color

func _move(delta: float) -> void:
	var flat := _dest - global_position
	flat.y = 0.0
	if flat.length() < 0.5:
		_dest = arena.random_point(0.8)
		_dest.y = global_position.y
		if _visual:
			_visual.play_idle()
		return
	global_position += flat.normalized() * data.move_speed * delta
	if _visual:
		_visual.play_move()

func _shoot(delta: float) -> void:
	if not armed:
		return
	for i in data.patterns.size():
		_timers[i] -= delta
		if _timers[i] <= 0.0:
			var p := data.patterns[i]
			_timers[i] = p.interval
			p.fire(global_position, target.global_position, arena, _steps[i])
			_steps[i] += 1

func take_damage(amount: float) -> void:
	hp -= amount
	_flash = 0.12
	if _visual:
		_visual.flash()
	_update_label()
	if hp <= 0.0:
		_dying = true
		defeated.emit(self)
		if _visual:
			var death_len := _visual.play_death()
			if death_len > 0.0:
				get_tree().create_timer(death_len).timeout.connect(queue_free)
				return
		queue_free()

func _update_label() -> void:
	_label.text = "%s  %d" % [data.display_name, maxi(0, ceili(hp))]
