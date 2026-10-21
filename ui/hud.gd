class_name Hud
extends Control
## Player meter cluster (portrait, HP, shield frame, stamina — custom-drawn
## bars, see ui/widgets/) plus level, XP, the control hint and the combo
## counter. All of the static layout — positions, sizes, which texture each
## bar uses — lives in hud.tscn now; open it in the editor to move or resize
## anything. This script just drives the live values and the damage-reaction
## animation (the portrait punch + HP bar shake).

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
@onready var _combo: Label = %ComboLabel

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

	_xp.max_value = s.xp_to_next()
	_xp.value = s.xp
	_level.text = "Lv %d   HP %d/%d   Shield %d/%d" % [s.level, s.hp, s.max_hp(), s.shield, s.max_shield()]
	_hint.text = "[Tab] Stats (%d pts)   [M] Travel" % s.points if s.points > 0 \
		else "[Tab] Stats   [M] Travel"

func _on_combo(c: int) -> void:
	_combo.text = "x%d" % c if c > 1 else ""

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
	if _hp_shake_tween and _hp_shake_tween.is_valid():
		_hp_shake_tween.kill()
	_hp_shake_tween = create_tween()
	var magnitude := HP_SHAKE_MAGNITUDE
	for i in HP_SHAKE_STEPS:
		var offset := Vector2(randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude))
		_hp_shake_tween.tween_property(_hp_group, "position", _hp_rest_pos + offset, HP_SHAKE_STEP_TIME)
		magnitude *= 0.6
	_hp_shake_tween.tween_property(_hp_group, "position", _hp_rest_pos, HP_SHAKE_STEP_TIME)
