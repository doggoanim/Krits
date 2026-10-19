class_name EnemyVisual
extends Node3D
## Optional animated model for an enemy, used in place of the plain
## procedural sphere when its EnemyData specifies one (see EnemyData.model).
## Mirrors PlayerVisual's approach via the shared ModelUtil — auto-scaled to
## a target height, cel-shaded, outlined — so an animated enemy reads as
## part of the same cast as the player, not a different art style bolted on.

const OUTLINE_THICKNESS_RATIO := 0.0   ## outline removed; raise above 0 to bring it back

var _anim: AnimationPlayer
var _model: Node3D
var _materials: Array[BaseMaterial3D] = []
var _base_colors: Dictionary = {}   # BaseMaterial3D -> Color, the non-flash color
var _flash_t := 0.0
var _anim_idle: StringName
var _anim_move: StringName
var _anim_death: StringName

## `data` supplies the model scene, target height and clip names (see
## EnemyData) — kept data-driven rather than hardcoded constants since,
## unlike the player, different enemies can use entirely different models.
func setup(data: EnemyData) -> void:
	_anim_idle = data.anim_idle
	_anim_move = data.anim_move
	_anim_death = data.anim_death
	_model = data.model.instantiate()
	add_child(_model)
	_model.rotation.y = data.model_facing_offset
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var fit_box := ModelUtil.fit_height(_model, data.model_height)
	var height := fit_box.size.y if fit_box.size.y > 0.001 else data.model_height
	ModelUtil.apply_cel_shading(_model, height * OUTLINE_THICKNESS_RATIO, Color.BLACK, _materials)
	for m in _materials:
		_base_colors[m] = m.albedo_color
	if _anim:
		for clip in [_anim_idle, _anim_move]:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	play_idle()

func play_idle() -> void:
	_play(_anim_idle)

func play_move() -> void:
	_play(_anim_move)

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

func _play(anim_name: StringName) -> void:
	if _anim == null or anim_name == &"" or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name and _anim.is_playing():
		return
	_anim.play(anim_name)

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		for m in _materials:
			m.albedo_color = Color.WHITE
	else:
		for m in _materials:
			if m.albedo_color != _base_colors.get(m, m.albedo_color):
				m.albedo_color = _base_colors[m]
