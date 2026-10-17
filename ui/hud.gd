class_name Hud
extends Control
## Health / shield / XP bars, level and combo counter.

var _hp: ProgressBar
var _shield: ProgressBar
var _xp: ProgressBar
var _level: Label
var _combo: Label
var _hint: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	box.custom_minimum_size = Vector2(320, 0)
	add_child(box)
	_level = Label.new()
	box.add_child(_level)
	_hp = _bar(box, Color(0.9, 0.2, 0.25))
	_shield = _bar(box, Color(0.3, 0.7, 1.0))
	_xp = _bar(box, Color(0.9, 0.8, 0.2))
	_xp.custom_minimum_size.y = 8
	_hint = Label.new()
	box.add_child(_hint)

	_combo = Label.new()
	_combo.add_theme_font_size_override("font_size", 44)
	_combo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo.position = Vector2(-60, 40)
	add_child(_combo)

	Events.player_damaged.connect(func(_a, _b): _refresh())
	Events.stats_changed.connect(_refresh)
	Events.combo_changed.connect(_on_combo)
	_refresh()

func _bar(parent: Node, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(320, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b

func _process(_delta: float) -> void:
	_refresh()   # shield recharges every frame

func _refresh() -> void:
	var s := Game.stats
	_hp.max_value = s.max_hp()
	_hp.value = s.hp
	_shield.max_value = s.max_shield()
	_shield.value = s.shield
	_xp.max_value = s.xp_to_next()
	_xp.value = s.xp
	_level.text = "Lv %d   HP %d/%d   Shield %d/%d" % [s.level, s.hp, s.max_hp(), s.shield, s.max_shield()]
	_hint.text = "[Tab] Stats (%d pts)   [M] Travel   [O] Outfits" % s.points if s.points > 0 \
		else "[Tab] Stats   [M] Travel   [O] Outfits"

func _on_combo(c: int) -> void:
	_combo.text = "x%d" % c if c > 1 else ""
