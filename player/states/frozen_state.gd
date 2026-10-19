class_name FrozenState
extends PlayerState
## Cinematic hold (encounter float). No input, no gravity; scripts move the player.

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	player.velocity = Vector3.ZERO
	player.set_crouching(false)
	player.visual.play(PlayerVisual.ANIM_IDLE)
