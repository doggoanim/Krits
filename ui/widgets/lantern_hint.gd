class_name LanternHint
extends Control
## The lantern's wordless control hint, centred near the top of the screen: a
## key plate showing the (rebindable) toggle key beside an on/off switch.
##
## - First time the player owns the lantern it appears and stays until they
##   switch it for the first time (remembered as the flag `tutorial_lantern`).
## - After that it only pops up for a moment each time they toggle, showing the
##   switch's new position.

const FADE_TIME := 0.25
const HOLD_TIME := 1.4   ## seconds shown after a toggle

@export var switch_on: Texture2D
@export var switch_off: Texture2D

@onready var _key: Label = %Key
@onready var _switch: TextureRect = %Switch

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	Events.item_gained.connect(_on_item_gained)
	Events.lantern_toggled.connect(_on_toggled)
	_show_if_unlearned.call_deferred()   # a loaded save may already own it

func _on_item_gained(id: StringName, _count: int) -> void:
	if id == HipLantern.ITEM_ID:
		_show_if_unlearned()

func _show_if_unlearned() -> void:
	if Game.inventory != null and Game.inventory.has(HipLantern.ITEM_ID) \
			and not Game.flag(&"tutorial_lantern"):
		_present(true)

func _on_toggled(_lit: bool) -> void:
	Game.set_flag(&"tutorial_lantern")   # learned the first time they switch it
	_present(false)

## Shows the hint. `hold` keeps it up until the first toggle; otherwise it
## fades out after HOLD_TIME.
func _present(hold: bool) -> void:
	_key.text = InputSetup.key_label(Settings.get_binding(HipLantern.ACTION))
	_switch.texture = switch_on if HipLantern.lit else switch_off
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	if not hold:
		_tween.tween_interval(HOLD_TIME)
		_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME * 2.0)
