class_name Hud
extends Control
## Player meter cluster (portrait, HP, shield frame, stamina — custom-drawn
## bars, see ui/widgets/) plus gold, the control hint and the combo counter.
## All of the static layout — positions, sizes, which texture each bar uses —
## lives in hud.tscn now; open it in the editor to move or resize anything.
## This script just drives the live values and the damage-reaction animation
## (the portrait punch + HP bar shake).
##
## %LevelLabel/%XpBar are hud.tscn's old names from when stats were
## level-based — kept as-is rather than renamed in the scene file (pure
## churn, no behavior change) now that stats are equipment-driven; the label
## shows gold these days and the bar just stays hidden (see _refresh()).

## -- Damage reaction ------------------------------------------------------
## Taking a hit (not healing — see _on_player_damaged()) punches the portrait
## (a quick size bounce + a flash to red, both on _portrait_group so the live
## render and its frame art move/flash together as one piece) and shakes the
## HP bar (_hp_group, jittered off its resting position and sprung back).
const PORTRAIT_HIT_SCALE := 1.18
const PORTRAIT_HIT_SCALE_TIME := 0.25
const PORTRAIT_HIT_FLASH_COLOR := Color(1.0, 0.25, 0.25)
const PORTRAIT_HIT_FLASH_TIME := 0.3
const HP_SHAKE_STEPS := 5
const HP_SHAKE_MAGNITUDE := 6.0
const HP_SHAKE_STEP_TIME := 0.04

## Node paths resolved via hud.tscn's unique names (%Name) — see that scene
## for where each one actually sits.
@onready var _hp_group: Control = %HpGroup   ## wraps the HP track/fill/shield-outline bars — shaken as one unit
@onready var _hp_fill: TexturedSlantedBar = %Fill
@onready var _shield_outline: TexturedSlantedBar = %ShieldOutline
@onready var _stamina_fill: TexturedSlantedBar = %StaminaFill
@onready var _portrait_group: Control = %PortraitGroup   ## wraps the portrait frame art + live render — bounced/flashed as one unit
@onready var _level: Label = %LevelLabel
@onready var _xp: ProgressBar = %XpBar
@onready var _hint: Label = %HintLabel
@onready var _combo_plate: PanelContainer = %ComboPlate   ## small hand-drawn plate beside the bars
@onready var _pound_plate: PanelContainer = %PoundPlate   ## shown under the combo plate on a ground-pound bonus
@onready var _combo: Label = %ComboLabel

## -- Combo plate ----------------------------------------------------------
## Pops on every combo step, warms up in colour every COMBO_PER_TIER steps,
## and (Sword) slams to the damage total when the combo lands, then fades.
@export var combo_plate_styles: Array[StyleBox] = []   ## one picked at random per pop
const COMBO_TIER_COLORS := [Color(1, 1, 1), Color(1, 0.93, 0.5), Color(1, 0.72, 0.4), Color(1, 0.5, 0.45), Color(1, 0.55, 0.85)]
const COMBO_PER_TIER := 3
var _combo_tween: Tween
var _pound_tween: Tween
@onready var _toasts: VBoxContainer = %Toasts   ## pickup notices, top right
var _combo_slamming := false

var _hp_rest_pos: Vector2   ## _hp_group's resting position, read from the scene so the shake
							## always springs back to wherever it's actually placed
var _portrait_tween: Tween
var _hp_shake_tween: Tween

var _last_hp := 0.0
var _last_shield := 0.0

func _ready() -> void:
	_hp_rest_pos = _hp_group.position

	_last_hp = Game.stats.hp
	_last_shield = Game.stats.shield
	Events.player_damaged.connect(_on_player_damaged)
	Events.stats_changed.connect(_refresh)
	Events.combo_changed.connect(_on_combo)
	Events.combo_landed.connect(_on_combo_landed)
	Events.item_gained.connect(_on_item_gained)
	Events.notice.connect(_toast)
	Events.inventory_full.connect(_on_inventory_full)
	_combo_plate.resized.connect(func() -> void: _combo_plate.pivot_offset = _combo_plate.size * 0.5)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()   # shield recharges every frame

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

	# No more XP/levels (stats are equipment-driven now, see PlayerStats) —
	# the bar that used to track XP-to-next-level just stays hidden; the
	# label it sat next to now shows gold instead.
	_xp.visible = false
	_level.text = "Gold %d   HP %d/%d   Shield %d/%d" % [s.gold, s.hp, s.max_hp(), s.shield, s.max_shield()]
	_hint.text = "[%s] Inventory   [%s] Travel" % [
		InputSetup.key_label(Settings.get_binding(&"menu_inventory")),
		InputSetup.key_label(Settings.get_binding(&"menu_travel"))]

func _on_combo(c: int) -> void:
	if c <= 0:
		if not _combo_slamming:   # a landing slam hides itself when it's done
			_hide_combo_plate()
		return
	_combo_slamming = false
	_pound_plate.visible = false
	_combo.text = "x%d" % c
	var tier := mini((c - 1) / COMBO_PER_TIER, COMBO_TIER_COLORS.size() - 1)
	_combo_plate.modulate = COMBO_TIER_COLORS[tier]
	_pop_combo_plate(1.5, 0.4)

func _on_combo_landed(damage: float, _hits: int, pound_bonus: bool) -> void:
	_combo_slamming = true
	_combo.text = ("%d" if is_equal_approx(damage, roundf(damage)) else "%.1f") % damage
	_combo_plate.modulate = Color.WHITE
	_pop_combo_plate(1.8, 0.25)
	if pound_bonus:
		_show_pound_plate()
	_combo_tween.tween_interval(0.5)
	_combo_tween.tween_property(_combo_plate, "scale", Vector2.ZERO, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_combo_tween.tween_callback(func() -> void:
		_combo_slamming = false
		_combo_plate.visible = false)

## -- Pickup toasts ---------------------------------------------------------
func _on_item_gained(id: StringName, count: int) -> void:
	var item := ItemLibrary.by_id(id)
	if item:
		_toast("+%d %s" % [count, item.display_name])

func _on_inventory_full(id: StringName) -> void:
	var item := ItemLibrary.by_id(id)
	_toast("Bag full! Left behind: %s" % (item.display_name if item else String(id)))

## A small hand-drawn plate that pops in, waits and fades.
func _toast(text: String) -> void:
	var plate := PanelContainer.new()
	if not combo_plate_styles.is_empty():
		plate.add_theme_stylebox_override(&"panel", combo_plate_styles.pick_random())
	plate.size_flags_horizontal = Control.SIZE_SHRINK_END
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color.BLACK)
	label.add_theme_font_size_override(&"font_size", 34)
	plate.add_child(label)
	_toasts.add_child(plate)
	plate.modulate.a = 0.0
	plate.resized.connect(func() -> void: plate.pivot_offset = plate.size * 0.5)
	var tw := plate.create_tween()
	tw.tween_property(plate, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(plate, "scale", Vector2.ONE, 0.3).from(Vector2(1.3, 1.3)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(plate, "modulate:a", 0.0, 0.35)
	tw.tween_callback(plate.queue_free)

## The golden "POUND x1.25!" plate under the combo plate: pops, holds, shrinks.
func _show_pound_plate() -> void:
	if _pound_tween:
		_pound_tween.kill()
	_pound_plate.pivot_offset = _pound_plate.size * 0.5
	_pound_plate.visible = true
	_pound_plate.scale = Vector2.ONE * 2.0
	_pound_tween = create_tween()
	_pound_tween.tween_property(_pound_plate, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pound_tween.tween_interval(0.7)
	_pound_tween.tween_property(_pound_plate, "scale", Vector2.ZERO, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_pound_tween.tween_callback(func() -> void: _pound_plate.visible = false)

func _pop_combo_plate(from_scale: float, time: float) -> void:
	if not combo_plate_styles.is_empty():
		_combo_plate.add_theme_stylebox_override(&"panel", combo_plate_styles.pick_random())
	if _combo_tween:
		_combo_tween.kill()
	_combo_plate.visible = true
	_combo_plate.scale = Vector2.ONE * from_scale
	_combo_tween = create_tween()
	_combo_tween.tween_property(_combo_plate, "scale", Vector2.ONE, time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _hide_combo_plate() -> void:
	if _combo_tween:
		_combo_tween.kill()
	_combo_plate.visible = false

## Events.player_damaged also fires from PlayerStats.full_heal() (same signal,
## new hp/shield either way) — only punch the portrait/shake the bar when hp
## or shield actually went DOWN from last time, not on a heal.
func _on_player_damaged(hp: float, shield: float) -> void:
	if hp < _last_hp or shield < _last_shield:
		_punch_portrait()
		_shake_hp_bar()
	_last_hp = hp
	_last_shield = shield
	_refresh()

func _punch_portrait() -> void:
	if _portrait_tween and _portrait_tween.is_valid():
		_portrait_tween.kill()
	_portrait_group.scale = Vector2.ONE * PORTRAIT_HIT_SCALE
	_portrait_group.modulate = PORTRAIT_HIT_FLASH_COLOR
	_portrait_tween = create_tween()
	_portrait_tween.set_parallel(true)
	_portrait_tween.tween_property(_portrait_group, "scale", Vector2.ONE, PORTRAIT_HIT_SCALE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_portrait_tween.tween_property(_portrait_group, "modulate", Color.WHITE, PORTRAIT_HIT_FLASH_TIME)

## A few quick random jitters off the bar's resting position, shrinking each
## step, then settling exactly back — same idea as PlayerVisual.squash_stretch()'s
## pop, just on a 2D position instead of a 3D scale.
func _shake_hp_bar() -> void:
	if not Settings.get_value(&"accessibility/screen_shake"):
		return
	if _hp_shake_tween and _hp_shake_tween.is_valid():
		_hp_shake_tween.kill()
	_hp_shake_tween = create_tween()
	var magnitude := HP_SHAKE_MAGNITUDE
	for i in HP_SHAKE_STEPS:
		var offset := Vector2(randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude))
		_hp_shake_tween.tween_property(_hp_group, "position", _hp_rest_pos + offset, HP_SHAKE_STEP_TIME)
		magnitude *= 0.6
	_hp_shake_tween.tween_property(_hp_group, "position", _hp_rest_pos, HP_SHAKE_STEP_TIME)
