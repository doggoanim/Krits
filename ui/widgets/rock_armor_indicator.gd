class_name RockArmorIndicator
extends PanelContainer
## HUD plate shown for as long as the Earth spell's rock armor is up — the
## same hand-drawn plate treatment as the pound bonus ("POUND x1.25!"), in
## earth brown: "ROCK ARMOR x1.5!". It says nothing about how much shield is
## left (the HUD's shield bar shows that). Driven by Events.rock_armor_changed.
## The plate art and layout are assigned in hud.tscn.

@export var tint := Color(0.85, 0.6, 0.35)

var _last := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate = tint
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	Events.rock_armor_changed.connect(_on_changed)
	_on_changed(Game.stats.rock_shield, Game.stats.rock_shield_max)

func _on_changed(shield: float, _max_shield: float) -> void:
	var was_visible := visible
	visible = shield > 0.0
	if not visible:
		_last = 0.0
		return
	if not was_visible or shield < _last:   # pops on gaining armor and on every hit it soaks
		scale = Vector2(1.2, 1.2)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_last = shield
