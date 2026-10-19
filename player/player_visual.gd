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

## The "roll_loop" clip is just a held pose, not an actual spin, so the tumble
## itself is still done procedurally on the model's own rotation.x — same
## trick the old placeholder capsule used, just applied to the real model
## instead of a second body node.
const ROLL_SPIN_SPEED := 18.0   ## rad/s

## Blender's glTF export doesn't always agree with Godot's -Z-forward convention —
## a rig authored facing Blender's own "forward" often lands facing +Z in Godot,
## which makes every animation look reversed (the character appears to run
## backwards) even though the clips themselves are fine. One 180-degree turn
## around Y fixes it for every clip at once. Flip to 0.0 if a future re-export
## already faces -Z and this turns it backwards instead.
const MODEL_FACING_OFFSET := PI

var _anim: AnimationPlayer
var _model: Node3D
var _materials: Array[BaseMaterial3D] = []
var _outfit_materials: Array[BaseMaterial3D] = []
var _base_colors: Dictionary = {}   # BaseMaterial3D -> Color, the non-flash color
var _flash_t := 0.0
var _outfit: OutfitData
var _lean_pitch := 0.0   ## current smoothed forward/back lean (rad), this node's rotation.x
var _lean_bank := 0.0    ## current smoothed side-to-side lean (rad), this node's rotation.z
var _fit_aabb := AABB()
var _fit_has_box := false
var _base_scale := 1.0   ## uniform scale from _fit_model_height; set_crouch multiplies onto this
var _rolling := false     ## true while the model should be spinning on rotation.x
var _roll_burst_t := 0.0  ## >0 while a timed roll (e.g. wall bounce) is still running

func _ready() -> void:
	_model = MODEL_SCENE.instantiate()
	add_child(_model)
	_model.rotation.y = MODEL_FACING_OFFSET
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_collect_materials(_model)
	_fit_model_height()

	Events.outfit_changed.connect(func(id: StringName): apply_outfit(OutfitLibrary.get_outfit(id)))
	apply_outfit(OutfitLibrary.get_outfit(Game.outfit))
	play(ANIM_IDLE)

## Scales the whole model uniformly so its rest-pose height matches the
## player's actual capsule height, whatever units it was exported in — a
## cm-vs-m mismatch is the usual reason an import comes in 100x too big (or
## too small). Assumes the model's own origin already sits at its feet, same
## as Player's origin, so only a uniform scale is needed, no repositioning.
func _fit_model_height() -> void:
	_fit_has_box = false
	_fit_aabb = AABB()
	_accumulate_aabb(_model, Transform3D.IDENTITY)
	if not _fit_has_box or _fit_aabb.size.y <= 0.001:
		return
	_base_scale = Player.STAND_HEIGHT / _fit_aabb.size.y
	_model.scale = Vector3.ONE * _base_scale

func _accumulate_aabb(n: Node, parent_xform: Transform3D) -> void:
	var xform := parent_xform
	if n is Node3D:
		xform = parent_xform * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var box: AABB = xform * (n as MeshInstance3D).mesh.get_aabb()
		if _fit_has_box:
			_fit_aabb = _fit_aabb.merge(box)
		else:
			_fit_aabb = box
			_fit_has_box = true
	for c in n.get_children():
		_accumulate_aabb(c, xform)

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
## model down a bit on top of the height-fit scale. The actual crouch
## collision height is handled separately by Player.set_crouching.
func set_crouch(c: bool) -> void:
	if _model:
		_model.scale.y = _base_scale * (CROUCH_SCALE if c else 1.0)

func flash() -> void:
	_flash_t = 0.25

## Holds the roll pose and spin on for as long as `active` is true — used by
## RollState, which starts it on enter and stops it on exit (ground rolling
## lasts however long the player holds the button).
func set_roll(active: bool) -> void:
	_rolling = active
	_roll_burst_t = 0.0   # an explicit call always overrides a running burst
	if active:
		play(ANIM_ROLL)
	else:
		_model.rotation.x = 0.0

## A short, self-expiring tumble for flourishes that don't have their own
## state to call set_roll(false) when they're done — e.g. a wall bounce,
## which just lands back in AirState.
func play_roll_burst(duration: float) -> void:
	_rolling = true
	_roll_burst_t = duration
	play(ANIM_ROLL)

## True while the model is mid-spin (held roll or a timed burst). Other states
## check this before calling play() of their own, so they don't cut the roll
## pose short.
func is_rolling() -> bool:
	return _rolling

## Smoothly lean this node toward `pitch` (forward/back, rad) and `bank` (side-to-
## side, rad). Call every physics frame with a target of 0 to relax back upright.
func set_lean(pitch: float, bank: float, smoothing: float, delta: float) -> void:
	var t := clampf(smoothing * delta, 0.0, 1.0)
	_lean_pitch = lerpf(_lean_pitch, pitch, t)
	_lean_bank = lerpf(_lean_bank, bank, t)
	rotation.x = _lean_pitch
	rotation.z = _lean_bank

func _process(delta: float) -> void:
	if _roll_burst_t > 0.0:
		_roll_burst_t -= delta
		if _roll_burst_t <= 0.0:
			_rolling = false
			_model.rotation.x = 0.0
	if _rolling:
		_model.rotation.x -= delta * ROLL_SPIN_SPEED
	if _flash_t > 0.0:
		_flash_t -= delta
		var white := int(_flash_t * 30.0) % 2 == 0
		for m in _materials:
			m.albedo_color = Color.WHITE if white else _base_colors.get(m, m.albedo_color)
	else:
		for m in _materials:
			if m.albedo_color != _base_colors.get(m, m.albedo_color):
				m.albedo_color = _base_colors[m]
