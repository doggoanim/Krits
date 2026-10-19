class_name PlayerVisual
extends Node3D
## Loads the rigged character model and plays its baked-in animations.
## The model's AnimationPlayer owns the pose entirely (run/jump/dive/roll/pound);
## this node only owns facing (set by Player.face) and the movement lean (set by
## Player._update_lean), so the two layers never fight each other.

const MODEL_SCENE := preload("res://assets/player/krits.glb")

## Clip names baked into the model. Kept as constants so a renamed clip in a
## future export only needs updating here, not at every call site.
const ANIM_IDLE := &"idle"
const ANIM_RUN := &"run"
const ANIM_JUMP_START := &"jump_start"
const ANIM_FALLING := &"falling"
const ANIM_ROLL := &"roll_loop"
const ANIM_DIVE := &"air_dive"
const ANIM_LONG_JUMP := &"long_jump"
const ANIM_POUND := &"ground_pound"

## Material slots (named in the model) that get tinted by the active outfit.
## Skin/hair/face stay as authored — outfits only recolor the "clothing" parts.
const OUTFIT_SLOTS := [&"Body", &"Pants", &"Shoes"]
const CROUCH_SCALE := 0.65

var _anim: AnimationPlayer
var _model: Node3D
var _materials: Array[BaseMaterial3D] = []
var _outfit_materials: Array[BaseMaterial3D] = []
var _base_colors: Dictionary = {}   # BaseMaterial3D -> Color, the non-flash color
var _flash_t := 0.0
var _outfit: OutfitData
var _lean_pitch := 0.0   ## current smoothed forward/back lean (rad), this node's rotation.x
var _lean_bank := 0.0    ## current smoothed side-to-side lean (rad), this node's rotation.z

func _ready() -> void:
	_model = MODEL_SCENE.instantiate()
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_collect_materials(_model)

	Events.outfit_changed.connect(func(id: StringName): apply_outfit(OutfitLibrary.get_outfit(id)))
	apply_outfit(OutfitLibrary.get_outfit(Game.outfit))
	play(ANIM_IDLE)

func _collect_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count() if mi.mesh else 0:
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var dup := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				mi.set_surface_override_material(i, dup)
				_materials.append(dup)
				_base_colors[dup] = dup.albedo_color
				if dup.resource_name in OUTFIT_SLOTS:
					_outfit_materials.append(dup)
	for c in n.get_children():
		_collect_materials(c)

func apply_outfit(o: OutfitData) -> void:
	_outfit = o
	for m in _outfit_materials:
		m.albedo_color = o.color
		_base_colors[m] = o.color

## Plays `anim_name` if it isn't already the one running. Safe to call every
## frame — the common case (state hasn't changed) is a cheap no-op.
func play(anim_name: StringName, blend := 0.15) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name and _anim.is_playing():
		return
	_anim.play(anim_name, blend)

## Placeholder squash until the rig has a real crouch pose: just scales the
## model down a bit. The actual crouch collision height is handled separately
## by Player.set_crouching.
func set_crouch(c: bool) -> void:
	if _model:
		_model.scale.y = CROUCH_SCALE if c else 1.0

func flash() -> void:
	_flash_t = 0.25

## Smoothly lean this node toward `pitch` (forward/back, rad) and `bank` (side-to-
## side, rad). Call every physics frame with a target of 0 to relax back upright.
func set_lean(pitch: float, bank: float, smoothing: float, delta: float) -> void:
	var t := clampf(smoothing * delta, 0.0, 1.0)
	_lean_pitch = lerpf(_lean_pitch, pitch, t)
	_lean_bank = lerpf(_lean_bank, bank, t)
	rotation.x = _lean_pitch
	rotation.z = _lean_bank

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		var white := int(_flash_t * 30.0) % 2 == 0
		for m in _materials:
			m.albedo_color = Color.WHITE if white else _base_colors.get(m, m.albedo_color)
	else:
		for m in _materials:
			if m.albedo_color != _base_colors.get(m, m.albedo_color):
				m.albedo_color = _base_colors[m]
