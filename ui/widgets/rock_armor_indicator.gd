class_name RockArmorIndicator
extends PanelContainer
## HUD badge shown while the Earth spell's rock armor is up: its name, the
## damage bonus it grants and what's left of its separate shield. Hidden
## otherwise. Driven by Events.rock_armor_changed. The plate art is assigned
## in hud.tscn (`plate_style`) and tinted earth-brown here.

@export var plate_style: StyleBox
@export var tint := Color(0.85, 0.62, 0.38)

var _title: Label
var _amount: Label
var _bar: ProgressBar
var _last := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate = tint
	if plate_style:
		add_theme_stylebox_override(&"panel", plate_style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_title = _label("ROCK ARMOR   x%s DMG" % String.num(PlayerStats.ROCK_ARMOR_DAMAGE_MULT), 30)
	box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Orb.KIND_COLORS[Orb.Kind.EARTH][0]
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.45)
	back.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override(&"fill", fill)
	_bar.add_theme_stylebox_override(&"background", back)
	box.add_child(_bar)
	_amount = _label("", 28)
	box.add_child(_amount)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	Events.rock_armor_changed.connect(_on_changed)
	_on_changed(Game.stats.rock_shield, Game.stats.rock_shield_max)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override(&"font_color", Color.BLACK)
	l.add_theme_font_size_override(&"font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _on_changed(shield: float, max_shield: float) -> void:
	var was_visible := visible
	visible = shield > 0.0
	if not visible:
		_last = 0.0
		return
	_bar.max_value = max_shield
	_bar.value = shield
	_amount.text = "%d / %d" % [ceili(shield), int(max_shield)]
	if not was_visible or shield < _last:   # pops on gaining armor and on every hit it soaks
		scale = Vector2(1.18, 1.18)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_last = shield
