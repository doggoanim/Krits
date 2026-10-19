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
const ANIM_ROLL := &"roll"
const ANIM_DIVE := &"air_dive"
const ANIM_LONG_JUMP := &"long_jump"
const ANIM_POUND := &"ground_pound"
const ANIM_CROUCH_IDLE := &"crouch_idle"
const ANIM_CROUCH_WALK := &"crouch_walk"
const ANIM_ROLL_COLLISION := &"roll_collision"   ## bonking into a wall, grounded or airborne
const ANIM_SLIDE := &"slide"                     ## brief reaction to a sharp direction change

## Material slots (named in the model) that get tinted by the active outfit.
## Skin/hair/face stay as authored — outfits only recolor the "clothing" parts.
const OUTFIT_SLOTS := [&"Body", &"Pants", &"Shoes"]

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
var _base_scale := 1.0   ## uniform scale from _fit_model_height
var _hold_t := 0.0       ## >0 while a one-off reaction pose must not be interrupted
var _held_anim := &""    ## the anim play_hold() is currently protecting

@export var outline_enabled := true
@export var outline_thickness_ratio := 0.006   ## outline thickness, as a fraction of the character's height
@export var outline_color := Color.BLACK

## Squash & stretch pops. All code-driven (scale the whole model, not the
## skeleton), independent of whatever animation clip is playing, so they
## layer on top of jump_start/falling/idle/etc. instead of replacing them.
@export_group("Squash & Stretch")
@export var jump_stretch_y := 1.22      ## taller/thinner at the instant of launch
@export var jump_stretch_xz := 0.88
@export var land_squash_y := 0.78       ## shorter/wider at the instant of landing impact
@export var land_squash_xz := 1.14
@export var uncrouch_bounce_y := 1.12   ## small stretchy "pop" when standing back up
@export var uncrouch_bounce_xz := 0.94
@export var squash_stretch_time := 0.16   ## how long the spring-back to normal takes

var _squash_tween: Tween

## Clips meant to play on repeat for as long as their state lasts, rather than
## play once and hold a final frame. glTF import defaults every clip to
## non-looping, so without this a sustained roll (or just standing still past
## idle's own length) would play a fraction of a second then freeze — forcing
## it here means the actual loop behavior never depends on import settings.
const LOOPING_ANIMS := [ANIM_IDLE, ANIM_RUN, ANIM_ROLL, ANIM_CROUCH_IDLE, ANIM_CROUCH_WALK]

func _ready() -> void:
	_model = MODEL_SCENE.instantiate()
	add_child(_model)
	_model.rotation.y = MODEL_FACING_OFFSET
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_fit_model_height()   # before _collect_materials: outline thickness is sized off _fit_aabb
	_collect_materials(_model)
	_force_looping_clips()
	if _anim == null:
		push_warning("PlayerVisual: no AnimationPlayer found under the model — animations will not play.")
	else:
		print("PlayerVisual: clips found in model = ", _anim.get_animation_list())

	Events.outfit_changed.connect(func(id: StringName): apply_outfit(OutfitLibrary.get_outfit(id)))
	apply_outfit(OutfitLibrary.get_outfit(Game.outfit))
	play(ANIM_IDLE)

func _force_looping_clips() -> void:
	if _anim == null:
		return
	for anim_name in LOOPING_ANIMS:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

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
				# Toon ramp: lighting still reaches the character (so it gets a
				# shaded side and a lit side, and still reads as part of the
				# scene), but in a few hard-edged bands instead of a smooth PBR
				# gradient — the classic cel-shaded look — and with no shiny
				# specular highlight. Colors stay close to their authored albedo
				# rather than washing out with strong light.
				dup.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				dup.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				dup.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, dup)
				_materials.append(dup)
				_base_colors[dup] = dup.albedo_color
				if dup.resource_name in OUTFIT_SLOTS:
					_outfit_materials.append(dup)
		if outline_enabled:
			var height := _fit_aabb.size.y if _fit_has_box else Player.STAND_HEIGHT
			CelOutline.apply(mi, height * outline_thickness_ratio, outline_color)
	for c in n.get_children():
		_collect_materials(c)

func apply_outfit(o: OutfitData) -> void:
	_outfit = o
	for m in _outfit_materials:
		m.albedo_color = o.color
		_base_colors[m] = o.color

## Plays `anim_name` if it isn't already the one running. Safe to call every
## frame — the common case (state hasn't changed) is a cheap no-op. Does
## nothing while a play_hold() reaction pose is still protected, unless it's
## that same clip — so a state's regular per-frame animation driver (Ground's
## run/idle, Air's jump/fall, ...) can keep calling this every frame without
## needing to know a reaction pose is in progress.
func play(anim_name: StringName, blend := 0.15) -> void:
	if _hold_t > 0.0 and anim_name != _held_anim:
		return
	if _anim == null:
		return
	if not _anim.has_animation(anim_name):
		push_warning("PlayerVisual.play(): no clip named '%s' in this model" % anim_name)
		return
	if _anim.current_animation == anim_name and _anim.is_playing():
		return
	_anim.play(anim_name, blend)

func flash() -> void:
	_flash_t = 0.25

## Plays a one-off reaction pose (a wall collision, say) and protects it from
## being overridden by a state's regular per-frame play() calls for
## `duration` seconds. Whoever triggered it is responsible for playing
## whatever comes next once that window has passed (is_holding() tells you
## when it's safe to).
func play_hold(anim_name: StringName, duration: float) -> void:
	_hold_t = duration
	_held_anim = anim_name
	play(anim_name)

## True while a play_hold() reaction pose is still protected.
func is_holding() -> bool:
	return _hold_t > 0.0

## Code-driven squash/stretch "pop": immediately pushes the whole model's
## scale away from its normal rest size — `y_scale` vertically, `xz_scale`
## horizontally (pick values on opposite sides of 1.0, e.g. tall+thin for a
## stretch or short+wide for a squash, so it still reads as the same
## character rather than literally growing/shrinking) — then eases back to
## normal over `duration` with a springy overshoot. Safe to call again
## mid-pop (a new call cancels and replaces whatever pop is still settling).
## `duration < 0` (the default) uses `squash_stretch_time` — can't reference
## that exported var directly as the default since GDScript requires default
## argument values to be constant expressions.
func squash_stretch(y_scale: float, xz_scale: float, duration := -1.0) -> void:
	var dur := duration if duration >= 0.0 else squash_stretch_time
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_model.scale = Vector3(_base_scale * xz_scale, _base_scale * y_scale, _base_scale * xz_scale)
	_squash_tween = create_tween()
	_squash_tween.tween_property(_model, "scale", Vector3.ONE * _base_scale, dur) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Smoothly lean this node toward `pitch` (forward/back, rad) and `bank` (side-to-
## side, rad). Call every physics frame with a target of 0 to relax back upright.
func set_lean(pitch: float, bank: float, smoothing: float, delta: float) -> void:
	var t := clampf(smoothing * delta, 0.0, 1.0)
	_lean_pitch = lerpf(_lean_pitch, pitch, t)
	_lean_bank = lerpf(_lean_bank, bank, t)
	rotation.x = _lean_pitch
	rotation.z = _lean_bank

func _process(delta: float) -> void:
	if _hold_t > 0.0:
		_hold_t = maxf(0.0, _hold_t - delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		var white := int(_flash_t * 30.0) % 2 == 0
		for m in _materials:
			m.albedo_color = Color.WHITE if white else _base_colors.get(m, m.albedo_color)
	else:
		for m in _materials:
			if m.albedo_color != _base_colors.get(m, m.albedo_color):
				m.albedo_color = _base_colors[m]
