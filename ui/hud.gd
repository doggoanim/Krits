class_name Hud
extends Control
## Player meter cluster (portrait, HP, shield frame, stamina — custom-drawn,
## see ui/widgets/) plus level, XP, the control hint and the combo counter,
## which stay plain Godot controls until a later design pass.

## -- Meter cluster layout -------------------------------------------------
const PORTRAIT_POS := Vector2(20.0, 16.0)
const PORTRAIT_SIZE := 108.0

const BAR_SKEW := 34.0           ## horizontal lean shared by the HP bar and its shield frame
const HP_POS := Vector2(96.0, 22.0)   ## overlaps the portrait's right half, like the reference
const HP_SIZE := Vector2(340.0, 46.0)
const SHIELD_OUTLINE_WIDTH := 4.0

const STAMINA_POS := Vector2(96.0, 72.0)
const STAMINA_SIZE := Vector2(300.0, 26.0)

const TRACK_COLOR := Color(0.12, 0.12, 0.14, 0.85)
const HP_COLOR := Color(0.85, 0.16, 0.2)
const SHIELD_COLOR := Color(0.95, 0.78, 0.15)
const STAMINA_COLOR := Color(0.2, 0.55, 0.85)

const READOUT_POS := Vector2(20.0, 150.0)
const READOUT_WIDTH := 340.0

var _hp_fill: SlantedBar
var _shield_outline: SlantedBar
var _stamina_fill: SlantedBar

var _level: Label
var _xp: ProgressBar
var _hint: Label
var _combo: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_meter_cluster()
	_build_legacy_readout()

	Events.player_damaged.connect(func(_a, _b): _refresh())
	Events.stats_changed.connect(_refresh)
	Events.combo_changed.connect(_on_combo)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()   # shield recharges every frame

## Builds the stylized HP/shield/stamina cluster. Each meter is a stack of
## SlantedBar instances sharing one rect: a static full-width track behind,
## then the live value on top — the shield frame is a third layer, outline
## only, sharing the HP bar's rect/skew so it reads as a frame around it.
func _build_meter_cluster() -> void:
	_make_bar(HP_POS, HP_SIZE, BAR_SKEW, TRACK_COLOR)
	_hp_fill = _make_bar(HP_POS, HP_SIZE, BAR_SKEW, HP_COLOR)
	_shield_outline = _make_bar(HP_POS, HP_SIZE, BAR_SKEW, SHIELD_COLOR)
	_shield_outline.outline_only = true
	_shield_outline.outline_width = SHIELD_OUTLINE_WIDTH

	_make_bar(STAMINA_POS, STAMINA_SIZE, 0.0, TRACK_COLOR)
	_stamina_fill = _make_bar(STAMINA_POS, STAMINA_SIZE, 0.0, STAMINA_COLOR)

	# Drawn last so the circle sits on top, capping the bars' left ends the
	# way the reference shows them emerging from behind the portrait.
	var portrait := PortraitSlot.new()
	portrait.position = PORTRAIT_POS
	portrait.size = Vector2.ONE * PORTRAIT_SIZE
	add_child(portrait)

func _make_bar(pos: Vector2, sz: Vector2, skew: float, color: Color) -> SlantedBar:
	var b := SlantedBar.new()
	b.position = pos
	b.size = sz
	b.skew = skew
	b.fill_color = color
	add_child(b)
	return b

func _build_legacy_readout() -> void:
	var box := VBoxContainer.new()
	box.position = READOUT_POS
	box.custom_minimum_size = Vector2(READOUT_WIDTH, 0.0)
	add_child(box)
	_level = Label.new()
	box.add_child(_level)
	_xp = ProgressBar.new()
	_xp.show_percentage = false
	_xp.custom_minimum_size = Vector2(READOUT_WIDTH, 8.0)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.9, 0.8, 0.2)
	_xp.add_theme_stylebox_override("fill", xp_fill)
	box.add_child(_xp)
	_hint = Label.new()
	box.add_child(_hint)

	_combo = Label.new()
	_combo.add_theme_font_size_override("font_size", 44)
	_combo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo.position = Vector2(-60, 40)
	add_child(_combo)

func _refresh() -> void:
	var s := Game.stats
	_hp_fill.max_value = s.max_hp()
	_hp_fill.value = s.hp
	_shield_outline.max_value = s.max_shield()
	_shield_outline.value = s.shield
	# Stamina has no gameplay source yet (reserved for future abilities) —
	# shown full until something drains it.
	_stamina_fill.max_value = 1.0
	_stamina_fill.value = 1.0

	_xp.max_value = s.xp_to_next()
	_xp.value = s.xp
	_level.text = "Lv %d   HP %d/%d   Shield %d/%d" % [s.level, s.hp, s.max_hp(), s.shield, s.max_shield()]
	_hint.text = "[Tab] Stats (%d pts)   [M] Travel   [O] Outfits" % s.points if s.points > 0 \
		else "[Tab] Stats   [M] Travel   [O] Outfits"

func _on_combo(c: int) -> void:
	_combo.text = "x%d" % c if c > 1 else ""
