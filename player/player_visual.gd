class_name PlayerVisual
extends Node3D
## Placeholder body built from primitives, tinted by the active outfit.
## Swap the meshes for a real model later; the public API stays the same.

var _body: MeshInstance3D
var _head: MeshInstance3D
var _mat := StandardMaterial3D.new()
var _flash_t := 0.0
var _rolling := false
var _outfit: OutfitData

func _ready() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.position.y = 0.7
	_body.material_override = _mat
	add_child(_body)

	var nose := MeshInstance3D.new()   # marks the facing direction (-Z)
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.35)
	nose.mesh = box
	nose.position = Vector3(0, 1.2, -0.4)
	add_child(nose)

	Events.outfit_changed.connect(func(id: StringName): apply_outfit(OutfitLibrary.get_outfit(id)))
	apply_outfit(OutfitLibrary.get_outfit(Game.outfit))

func apply_outfit(o: OutfitData) -> void:
	_outfit = o
	_mat.albedo_color = o.color
	_mat.metallic = o.metallic

func set_crouch(c: bool) -> void:
	if _body:
		_body.scale.y = 0.65 if c else 1.0
		_body.position.y = 0.45 if c else 0.7

func set_roll(r: bool) -> void:
	_rolling = r
	if not r:
		_body.rotation.x = 0.0

func set_pose(pose: StringName) -> void:
	match pose:
		&"dive": _body.rotation.x = deg_to_rad(-80)
		&"long_jump": _body.rotation.x = deg_to_rad(-60)
		&"pound": _body.rotation.x = deg_to_rad(180)
		_: _body.rotation.x = 0.0

func flash() -> void:
	_flash_t = 0.25

func _process(delta: float) -> void:
	if _rolling:
		_body.rotation.x -= delta * 18.0
	if _outfit == null:
		return
	if _flash_t > 0.0:
		_flash_t -= delta
		_mat.albedo_color = Color.WHITE if int(_flash_t * 30.0) % 2 == 0 else _outfit.color
	else:
		_mat.albedo_color = _outfit.color
