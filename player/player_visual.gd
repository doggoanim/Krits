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
## Three interchangeable jump-start poses, picked at random each jump (see
## roll_jump_start()/jump_start_anim()) instead of always playing the same one.
const ANIM_JUMP_START_VARIANTS: Array[StringName] = [&"jump_start1", &"jump_start2", &"jump_start3"]
## Three interchangeable orb-hit attack poses, picked at random each hit (see
## play_random_attack()).
const ANIM_ATTACK_VARIANTS: Array[StringName] = [&"attack1", &"attack2", &"attack3"]
const ANIM_FALLING := &"falling"
const ANIM_ROLL := &"roll"
const ANIM_DIVE := &"air_dive"
const ANIM_LONG_JUMP := &"long_jump"
const ANIM_POUND := &"ground_pound"
const ANIM_POUND_LAND := &"ground_pound_land"   ## held recovery pose after the slam impacts
const ANIM_CROUCH_IDLE := &"crouch_idle"
const ANIM_CROUCH_WALK := &"crouch_walk"
const ANIM_ROLL_COLLISION := &"roll_collision"   ## bonking into a wall, grounded or airborne
const ANIM_SLIDE := &"slide"                     ## brief reaction to a sharp direction change
const ANIM_SIDE_JUMP := &"side_jump"             ## Mario 64-style skid-turn trick jump

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
var _base_scale := 1.0   ## uniform scale from ModelUtil.fit_height, read back after _ready()
var _hold_t := 0.0       ## >0 while a one-off reaction pose must not be interrupted
var _held_anim := &""    ## the anim play_hold() is currently protecting
var _jump_start_anim: StringName = ANIM_JUMP_START_VARIANTS[0]   ## this jump's picked pose
var _slimed := false     ## standing in a slime puddle — tints the character green (see set_slimed)

const SLIME_TINT_COLOR := Color(0x5A / 255.0, 0x8B / 255.0, 0x2F / 255.0)
const SLIME_TINT_STRENGTH := 0.6

@export var outline_enabled := true
@export var outline_thickness_ratio := 0.011   ## outline thickness, as a fraction of the character's height
@export var outline_color := Color.BLACK

## Squash & stretch pops. All code-driven (scale the whole model, not the
## skeleton), independent of whatever animation clip is playing, so they
## layer on top of jump_start/falling/idle/etc. instead of replacing them.
@export_group("Squash & Stretch")
@export var jump_stretch_y := 1.4      ## taller/thinner at the instant of launch
@export var jump_stretch_xz := 0.88
@export var land_squash_y := 0.78       ## shorter/wider at the instant of landing impact
@export var land_squash_xz := 1.3
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
	var fit_box := ModelUtil.fit_height(_model, Player.STAND_HEIGHT)
	_base_scale = _model.scale.x
	var height := fit_box.size.y if fit_box.size.y > 0.001 else Player.STAND_HEIGHT
	ModelUtil.apply_cel_shading(_model, height * outline_thickness_ratio if outline_enabled else 0.0,
			outline_color, _materials)
	for m in _materials:
		_base_colors[m] = m.albedo_color
		if m.resource_name in OUTFIT_SLOTS:
			_outfit_materials.append(m)
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

## The loaded model's root node — used by PlayerXray to build see-through
## duplicates of the same meshes (sharing the same skeleton, so they
## animate in sync automatically).
func get_model() -> Node3D:
	return _model

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

## Standing in a slime puddle: tints the character green for as long as this
## stays true (the dripping particles are PlayerEffects.set_slime_drip,
## driven alongside this from Player.enter_slime_puddle/exit_slime_puddle).
func set_slimed(active: bool) -> void:
	_slimed = active

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

## Picks a new random jump-start pose — call once when a jump begins (see
## Player.start_jump()). AirState then just calls jump_start_anim() every
## frame like it would any other per-frame animation, so the rest of the jump
## doesn't need to know a variant was picked at all.
func roll_jump_start() -> void:
	_jump_start_anim = ANIM_JUMP_START_VARIANTS.pick_random()

func jump_start_anim() -> StringName:
	return _jump_start_anim

## A random attack pose, protected like a wall-bounce reaction (play_hold)
## for `duration` — long enough to read as a punch, short enough not to
## stall an orb-combo chain waiting out the clip's full length. See
## Player.bounce_off_orb().
func play_random_attack(duration: float) -> void:
	play_hold(ANIM_ATTACK_VARIANTS.pick_random(), duration)

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
	elif _slimed:
		for m in _materials:
			m.albedo_color = _base_colors.get(m, m.albedo_color).lerp(SLIME_TINT_COLOR, SLIME_TINT_STRENGTH)
	else:
		for m in _materials:
			if m.albedo_color != _base_colors.get(m, m.albedo_color):
				m.albedo_color = _base_colors[m]
