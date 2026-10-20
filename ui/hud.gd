class_name Hud
extends Control
## Player meter cluster (portrait, HP, shield frame, stamina — custom-drawn,
## see ui/widgets/) plus level, XP, the control hint and the combo counter,
## which stay plain Godot controls until a later design pass.

## -- Meter cluster layout -------------------------------------------------
## HP fill, the shield frame and the stamina fill are now real art, cropped
## from the designer's mockup (assets/ui/top_left_hud.png) into three
## separate transparent-background textures — see TexturedSlantedBar for how
## a single flat mockup image still works as a live, drainable bar. The dark
## "track" behind each one stays a plain flat-color SlantedBar, since the
## mockup never drew an empty state to crop art from.
const HP_FILL_TEX := preload("res://assets/ui/hp_fill.png")
const SHIELD_FRAME_TEX := preload("res://assets/ui/shield_frame.png")
const STAMINA_FILL_TEX := preload("res://assets/ui/stamina_fill.png")

const PORTRAIT_POS := Vector2(20.0, 16.0)
const PORTRAIT_SIZE := 108.0

## BAR_SKEW matches the art's own slant (measured from the mockup: the top
## edge sits ~20px right of the bottom edge across its ~266px width).
const BAR_SKEW := 20.0
const HP_POS := Vector2(96.0, 22.0)   ## overlaps the portrait's right half, like the reference
const HP_SIZE := Vector2(340.0, 46.0)
const SHIELD_SIZE := Vector2(356.0, 54.0)   ## the shield_frame crop is a little wider/taller than
                                             ## the hp_fill one (the yellow border pokes past the
                                             ## red), so it gets its own size sharing HP_POS

const STAMINA_POS := Vector2(96.0, 72.0)
const STAMINA_SIZE := Vector2(300.0, 26.0)

const TRACK_COLOR := Color(0.12, 0.12, 0.14, 0.85)

const READOUT_POS := Vector2(20.0, 150.0)
const READOUT_WIDTH := 340.0

var _hp_fill: TexturedSlantedBar
var _shield_outline: TexturedSlantedBar
var _stamina_fill: TexturedSlantedBar

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

## Builds the stylized HP/shield/stamina cluster: a flat-color track behind
## each meter, then its real-art fill on top — the shield frame is its own
## textured layer sharing the HP bar's position/skew so it reads as a frame
## wrapping it, and because its texture is just border strokes on a
## transparent interior, "draining" it still looks like an outline shrinking
## in from the right, not a filled shape.
func _build_meter_cluster() -> void:
	_make_track(HP_POS, HP_SIZE, BAR_SKEW)
	_hp_fill = _make_textured_bar(HP_POS, HP_SIZE, BAR_SKEW, HP_FILL_TEX)
	_shield_outline = _make_textured_bar(HP_POS, SHIELD_SIZE, BAR_SKEW, SHIELD_FRAME_TEX)

	_make_track(STAMINA_POS, STAMINA_SIZE, 0.0)
	_stamina_fill = _make_textured_bar(STAMINA_POS, STAMINA_SIZE, 0.0, STAMINA_FILL_TEX)

	# Layered last so the whole portrait sits on top, capping the bars' left
	# ends the way the reference shows them emerging from behind it:
	# a grey fallback disc, the live 3D render over it, then the ring on top.
	var portrait_bg := PortraitSlot.new()
	portrait_bg.position = PORTRAIT_POS
	portrait_bg.size = Vector2.ONE * PORTRAIT_SIZE
	portrait_bg.outline_width = 0.0
	add_child(portrait_bg)

	var portrait_view := PortraitViewport.new()
	portrait_view.position = PORTRAIT_POS
	portrait_view.size = Vector2.ONE * PORTRAIT_SIZE
	add_child(portrait_view)

	var portrait_ring := PortraitSlot.new()
	portrait_ring.position = PORTRAIT_POS
	portrait_ring.size = Vector2.ONE * PORTRAIT_SIZE
	portrait_ring.draw_fill = false
	add_child(portrait_ring)

func _make_track(pos: Vector2, sz: Vector2, skew: float) -> SlantedBar:
	var b := SlantedBar.new()
	b.position = pos
	b.size = sz
	b.skew = skew
	b.fill_color = TRACK_COLOR
	add_child(b)
	return b

func _make_textured_bar(pos: Vector2, sz: Vector2, skew: float, tex: Texture2D) -> TexturedSlantedBar:
	var b := TexturedSlantedBar.new()
	b.position = pos
	b.size = sz
	b.skew = skew
	b.texture = tex
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
