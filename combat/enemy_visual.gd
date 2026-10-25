class_name EnemyVisual
extends Node3D
## Optional animated model for an enemy, used in place of the plain
## procedural sphere when its EnemyData specifies one (see EnemyData.model).
## Mirrors PlayerVisual's approach via the shared ModelUtil — auto-scaled to
## a target height, cel-shaded, outlined — so an animated enemy reads as
## part of the same cast as the player, not a different art style bolted on.

const OUTLINE_THICKNESS_RATIO := 0.015   ## black inverted-hull outline, as a fraction of the model's height

var _anim: AnimationPlayer
var _model: Node3D
var _materials: Array[ShaderMaterial] = []
var _base_colors: Dictionary = {}   # ShaderMaterial -> Color, the non-flash color (see ModelUtil.get/set_tint)
var _flash_t := 0.0
var _anim_idle: StringName
var _anim_move: StringName
var _anim_death: StringName
var _anim_leap_ready: StringName
var _anim_leap: StringName
var _anim_shoot: StringName

## `data` supplies the model scene, target height and clip names (see
## EnemyData) — kept data-driven rather than hardcoded constants since,
## unlike the player, different enemies can use entirely different models.
func setup(data: EnemyData) -> void:
	_anim_idle = data.anim_idle
	_anim_move = data.anim_move
	_anim_death = data.anim_death
	_anim_leap_ready = data.anim_leap_ready
	_anim_leap = data.anim_leap
	_anim_shoot = data.anim_shoot
	_model = data.model.instantiate()
	add_child(_model)
	_model.rotation.y = data.model_facing_offset
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var fit_box := ModelUtil.fit_height(_model, data.model_height)
	var height := fit_box.size.y if fit_box.size.y > 0.001 else data.model_height
	ModelUtil.apply_cel_shading(_model, height * OUTLINE_THICKNESS_RATIO, Color.BLACK, _materials)
	for m in _materials:
		_base_colors[m] = ModelUtil.get_tint(m)
	if _anim:
		for clip in [_anim_idle, _anim_move]:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	play_idle()

func play_idle() -> void:
	_play(_anim_idle)

func play_move() -> void:
	_play(_anim_move)

func play_leap_ready() -> void:
	_play(_anim_leap_ready)

func play_leap() -> void:
	_play(_anim_leap)

## Restarts every call (unlike the others) — a burst fires several shots in a
## row and each one should re-trigger the pose, not just hold whatever frame
## the previous shot's playback happened to be on.
func play_shoot() -> void:
	_play(_anim_shoot, true)

## Plays the death clip, if any, and reports back how long it runs for (so
## the caller can delay removing the enemy until it's finished instead of
## cutting the animation off instantly). Returns 0.0 if there's no clip.
func play_death() -> float:
	if _anim == null or _anim_death == &"" or not _anim.has_animation(_anim_death):
		return 0.0
	_anim.play(_anim_death)
	return _anim.get_animation(_anim_death).length

func flash() -> void:
	_flash_t = 0.12

func _play(anim_name: StringName, restart := false) -> void:
	if _anim == null or anim_name == &"" or not _anim.has_animation(anim_name):
		return
	if not restart and _anim.current_animation == anim_name and _anim.is_playing():
		return
	_anim.play(anim_name)

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		for m in _materials:
			ModelUtil.set_tint(m, Color.WHITE)
	else:
		for m in _materials:
			var base: Color = _base_colors.get(m, ModelUtil.get_tint(m))
			if ModelUtil.get_tint(m) != base:
				ModelUtil.set_tint(m, base)
