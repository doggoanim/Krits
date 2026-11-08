@tool
class_name TutorialPopupTrigger
extends Node3D
## Asks for a pausing "[key] to ..." card (see TutorialPopup) once, either
##  * when the player walks into its box (leave `when_states` empty), or
##  * when the player enters one of `when_states` (a player state id such as
##    Crouch or Pound), anywhere in the level — "after doing it" chains.
## `requires_flag` (e.g. "tutorial_crouch_pound", the flag a finished card
## leaves behind) holds the trigger back until an earlier card was seen. The
## card remembers itself as `tutorial_<popup_id>`, so this never repeats.

@export var popup_id: StringName = &""
@export var action: StringName = &"jump"
@export_multiline var text := "to jump"   ## BBCode, shown after the key plate
@export var when_states: Array[StringName] = []
@export var delay := 0.0   ## seconds to wait before the card opens (so it does not pounce the instant a move starts)
@export var requires_flag: StringName = &""
@export var size := Vector3(6, 4, 6):
	set(v):
		size = v
		_refresh_preview()

var _preview: MeshInstance3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_preview()
		return
	if Game.flag(StringName("tutorial_%s" % popup_id)):
		return
	if when_states.is_empty():
		_build_zone()
	else:
		Events.player_state_changed.connect(_on_player_state)

func _build_zone() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1 << 1   # layer 2: the player
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_request())

func _on_player_state(state: StringName) -> void:
	if state in when_states:
		_request()

func _request() -> void:
	if requires_flag != &"" and not Game.flag(requires_flag):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	Events.tutorial_popup_requested.emit(popup_id, action, text)

## Editor-only wireframe of the trigger box so it can be placed by eye.
func _refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.3, 0.18)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_preview.material_override = mat
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var mesh := BoxMesh.new()
	mesh.size = size
	_preview.mesh = mesh
