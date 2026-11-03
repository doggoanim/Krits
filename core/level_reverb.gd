class_name LevelReverb
extends Node
## A reverb on the Master bus that a level can switch on (see LevelEnvironment:
## reverb_enabled and friends) — caves and wells get an echo, everywhere else
## stays dry. Main owns one and calls apply() whenever a level loads; the wet
## level fades in/out, and the effect is switched fully off while dry so it
## costs nothing outdoors.

const FADE_TIME := 0.6

var _effect := AudioEffectReverb.new()
var _bus_idx := -1
var _effect_idx := -1
var _tween: Tween

func _ready() -> void:
	_bus_idx = AudioServer.get_bus_index(&"Master")
	_effect.dry = 1.0
	_effect.wet = 0.0
	AudioServer.add_bus_effect(_bus_idx, _effect)
	_effect_idx = AudioServer.get_bus_effect_count(_bus_idx) - 1
	AudioServer.set_bus_effect_enabled(_bus_idx, _effect_idx, false)

func _exit_tree() -> void:
	if _effect_idx >= 0:
		AudioServer.remove_bus_effect(_bus_idx, _effect_idx)

## `env` = the level's LevelEnvironment, or null for a plain dry level.
func apply(env: LevelEnvironment) -> void:
	var target_wet := 0.0
	if env != null and env.reverb_enabled:
		_effect.room_size = env.reverb_room_size
		_effect.damping = env.reverb_damping
		_effect.predelay_msec = env.reverb_predelay_msec
		target_wet = env.reverb_wet
		AudioServer.set_bus_effect_enabled(_bus_idx, _effect_idx, true)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_effect, "wet", target_wet, FADE_TIME)
	if target_wet <= 0.0:
		_tween.tween_callback(AudioServer.set_bus_effect_enabled.bind(_bus_idx, _effect_idx, false))
