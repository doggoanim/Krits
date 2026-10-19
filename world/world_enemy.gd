class_name WorldEnemy
extends CharacterBody3D
## Overworld enemy. Invisible until the player comes close, then pops in and
## wanders around its home. Touching it emits `touched` (EncounterManager takes over).

signal touched(enemy: WorldEnemy)

@export var enemy_id: StringName = &""        ## unique id; defeated ids are saved as cleared
@export var data: EnemyData
@export var spawn_radius := 22.0
@export var despawn_radius := 32.0
@export var wander_radius := 8.0
@export var gravity := 30.0

var frozen := false   ## set by the encounter sequence

var _awake := false
var _solid := false          ## true once the pop-in finished; only then can it be touched
var _home := Vector3.ZERO
var _dest := Vector3.ZERO
var _wait := 0.0
var _visual: Node3D         ## pop-in/sleep wrapper (scaled 0..1 by _wake/_sleep)
var _model_visual: EnemyVisual   ## set only when data.model is used, for idle/move animation
var _contact: Area3D
var _player: Player
var _tween: Tween

func _ready() -> void:
	if enemy_id != &"" and Game.flag(_cleared_key(), false):
		queue_free()
		return
	add_to_group(&"world_enemies")
	collision_layer = 1 << 2   # layer 3: enemy
	collision_mask = 1
	_home = global_position
	_dest = _home

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.7 * data.size
	cs.shape = sh
	cs.position.y = 0.7 * data.size
	add_child(cs)

	_visual = Node3D.new()
	add_child(_visual)
	var label_height: float
	if data.model:
		_model_visual = EnemyVisual.new()
		_visual.add_child(_model_visual)
		_model_visual.setup(data)
		label_height = data.model_height * 1.3
	else:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.7 * data.size
		sm.height = 1.4 * data.size
		mi.mesh = sm
		mi.position.y = 0.7 * data.size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = data.color
		mat.emission_enabled = true
		mat.emission = data.color
		mat.emission_energy_multiplier = 0.4
		# Cel-shaded to match the character: hard light/shadow bands, no shiny highlight.
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mi.material_override = mat
		_visual.add_child(mi)
		label_height = 1.4 * data.size
	var lbl := Label3D.new()
	lbl.text = data.display_name
	lbl.position.y = label_height
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual.add_child(lbl)

	_contact = Area3D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 1 << 1
	var cc := CollisionShape3D.new()
	var cshape := SphereShape3D.new()
	cshape.radius = 1.2 * data.size
	cc.shape = cshape
	cc.position.y = 0.7 * data.size
	_contact.add_child(cc)
	add_child(_contact)
	_set_dormant_visuals()

func is_awake() -> bool:
	return _awake

## Called when the player wins: persist and remove.
func defeat() -> void:
	if enemy_id != &"":
		Game.set_flag(_cleared_key(), true)
	queue_free()

func _cleared_key() -> StringName:
	return StringName("cleared_" + str(enemy_id))

func _physics_process(delta: float) -> void:
	if frozen:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if not _awake and dist <= spawn_radius:
		_wake()
	elif _awake and dist > despawn_radius:
		_sleep()
	if not _awake:
		return
	_wander(delta)
	if _solid and not _player.dead:
		for b in _contact.get_overlapping_bodies():
			if b == _player:
				touched.emit(self)
				break

func _wander(delta: float) -> void:
	var flat := _dest - global_position
	flat.y = 0.0
	if _wait > 0.0:
		_wait -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _model_visual:
			_model_visual.play_idle()
	elif flat.length() < 0.5:
		_wait = randf_range(0.6, 2.0)
		var a := randf() * TAU
		_dest = _home + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.0, wander_radius)
		if _model_visual:
			_model_visual.play_idle()
	else:
		var dir := flat.normalized()
		velocity.x = dir.x * data.move_speed * 0.6
		velocity.z = dir.z * data.move_speed * 0.6
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 8.0 * delta))
		if _model_visual:
			_model_visual.play_move()
	velocity.y = -1.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()

func _wake() -> void:
	_awake = true
	_visual.visible = true
	_contact.monitoring = true
	_kill_tween()
	_visual.scale = Vector3.ZERO
	_tween = create_tween()
	_tween.tween_property(_visual, "scale", Vector3.ONE, 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _solid = true)

func _sleep() -> void:
	_awake = false
	_solid = false
	_contact.monitoring = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_visual, "scale", Vector3.ZERO, 0.3)
	_tween.tween_callback(func():
		global_position = _home
		velocity = Vector3.ZERO
		_dest = _home
		_set_dormant_visuals())

func _set_dormant_visuals() -> void:
	_visual.visible = false
	_visual.scale = Vector3.ZERO
	_contact.monitoring = false

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
