class_name Hud
extends Control
## Player meter cluster (portrait, HP, shield frame, stamina — custom-drawn,
## see ui/widgets/) plus level, XP, the control hint and the combo counter,
## which stay plain Godot controls until a later design pass.

## -- Meter cluster layout -------------------------------------------------
## HP fill, the shield frame, the stamina fill and the portrait frame are all
## real art now (assets/ui/*.png — the *_crop/*_fill ones are this file's own
## tight crops of whatever the designer last exported full-canvas, done once
## in a scratch script rather than checked in as a build step; re-crop by
## hand if the source art changes). See TexturedSlantedBar for how a single
## piece of flat art still works as a live, drainable bar. The track behind
## each meter is the same art again, dimmed (see TexturedSlantedBar.tint),
## since the art doesn't (yet) draw a separate empty state of its own — a
## plain rectangle there would peek out past the art's rounded corners. None
## of these are skewed any more — the redrawn art is a straight rounded bar,
## not a slanted parallelogram, so every bar below uses skew = 0.
const HP_FILL_TEX := preload("res://assets/ui/health_fill.png")
const SHIELD_FRAME_TEX := preload("res://assets/ui/shield_frame_crop.png")
const STAMINA_FILL_TEX := preload("res://assets/ui/stamina_fill.png")
const PORTRAIT_FRAME_TEX := preload("res://assets/ui/portrait_frame_crop.png")

const PORTRAIT_POS := Vector2(20.0, 16.0)
const PORTRAIT_FRAME_SIZE := Vector2(130.0, 99.0)   ## matches portrait_frame_crop.png's own aspect
const PORTRAIT_VIEW_SIZE := Vector2(90.0, 90.0)     ## the live 3D render stays square (so the
                                                     ## character isn't stretched) and sits centered
                                                     ## inside the frame art, sized to fill it while
                                                     ## still leaving its hand-drawn border visible

const HP_POS := Vector2(96.0, 32.0)   ## overlaps the portrait's right half, like the reference
const HP_SIZE := Vector2(340.0, 66.0)       ## matches health_fill.png's aspect (294x57)
const STAMINA_POS := Vector2(96.0, 102.0)
const STAMINA_SIZE := Vector2(280.0, 58.0)  ## matches stamina_fill.png's aspect (254x53)

const TRACK_TINT := Color(0.3, 0.3, 0.32, 0.5)   ## dims the same art to stand in as its own empty track

const READOUT_POS := Vector2(20.0, 170.0)
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

## Builds the stylized HP/shield/stamina cluster: a dim, always-full "ghost"
## of each bar's own art behind it as its empty-state track (shaped exactly
## like the real art, unlike a plain rectangle, which would peek out past its
## rounded corners — see TexturedSlantedBar.tint), then the live fill on top.
## The shield frame is its own textured layer sharing the HP bar's
## position/size so it reads as a frame wrapping it, and because its texture
## is just border strokes on a transparent interior, "draining" it still
## looks like an outline shrinking in from the right, not a filled shape.
func _build_meter_cluster() -> void:
	_make_track(HP_POS, HP_SIZE, HP_FILL_TEX)
	_hp_fill = _make_textured_bar(HP_POS, HP_SIZE, HP_FILL_TEX)
	_shield_outline = _make_textured_bar(HP_POS, HP_SIZE, SHIELD_FRAME_TEX)

	_make_track(STAMINA_POS, STAMINA_SIZE, STAMINA_FILL_TEX)
	_stamina_fill = _make_textured_bar(STAMINA_POS, STAMINA_SIZE, STAMINA_FILL_TEX)

	# The frame art is a static backdrop (grey disc + its own hand-drawn
	# outline baked in one image); the live 3D render sits centered on top of
	# it, smaller than the frame so the border stays visible all the way
	# around — no separate "ring on top" layer needed any more.
	var portrait_bg := TextureRect.new()
	portrait_bg.texture = PORTRAIT_FRAME_TEX
	portrait_bg.position = PORTRAIT_POS
	portrait_bg.size = PORTRAIT_FRAME_SIZE
	portrait_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_bg.stretch_mode = TextureRect.STRETCH_SCALE
	portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_bg)

	var portrait_view := PortraitViewport.new()
	portrait_view.position = PORTRAIT_POS + (PORTRAIT_FRAME_SIZE - PORTRAIT_VIEW_SIZE) * 0.5
	portrait_view.size = PORTRAIT_VIEW_SIZE
	add_child(portrait_view)

func _make_track(pos: Vector2, sz: Vector2, tex: Texture2D) -> TexturedSlantedBar:
	var b := _make_textured_bar(pos, sz, tex)
	b.tint = TRACK_TINT
	return b

func _make_textured_bar(pos: Vector2, sz: Vector2, tex: Texture2D) -> TexturedSlantedBar:
	var b := TexturedSlantedBar.new()
	b.position = pos
	b.size = sz
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
