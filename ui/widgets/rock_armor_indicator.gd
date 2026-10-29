class_name RockArmorIndicator
extends PanelContainer
## The Earth spell's damage-bonus plate: the same hand-drawn plate treatment
## and pop as the pound bonus ("POUND x1.25!"), in earth brown — "ROCK ARMOR
## x1.5!". Like the pound plate it only shows when a hit lands with the bonus
## applied (Hud calls pop() from the landed-damage event while the armor is up),
## then fades. Plate art and layout are assigned in hud.tscn.

@export var tint := Color(0.85, 0.6, 0.35)

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate = tint

func pop() -> void:
	if _tween:
		_tween.kill()
	pivot_offset = size * 0.5
	visible = true
	scale = Vector2.ONE * 2.0
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.7)
	_tween.tween_property(self, "scale", Vector2.ZERO, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: visible = false)
