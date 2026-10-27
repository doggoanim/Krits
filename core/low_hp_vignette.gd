class_name LowHpVignette
extends Node
## Darkens and gently pulses the screen edges when the player's HP drops
## critical — same bolt-on CanvasLayer + ColorRect + shader pattern as
## OutlineSystem/PixelateEffect, except this one sits ABOVE the HUD
## (CANVAS_LAYER higher than UiRoot's default layer, 1): a low-HP warning is
## meant to read over menus too, not just the 3D scene underneath them.
##
## Usage: Main creates exactly one of these for the whole game — see
## main.gd. No setup() call needed; it reads Game.stats directly every
## frame, the same autoload the HUD's own HP bar already reads from.

const CANVAS_LAYER := 5

@export var low_hp_threshold := 0.3   ## hp / max_hp fraction below which this starts showing at all
@export var fade_speed := 3.0         ## how quickly intensity eases toward its target each frame —
									   ## keeps a single big hit from snapping the vignette instantly
									   ## to full strength, or a heal from yanking it away just as fast
@export var vignette_color := Color(0.5, 0.0, 0.0)
@export var pulse_speed := 2.4
@export var pulse_amount := 0.35      ## how much the pulse adds/subtracts from the base intensity

var _overlay_material: ShaderMaterial
var _intensity := 0.0

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = CANVAS_LAYER
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = preload("res://shading/vignette_overlay.gdshader")
	overlay.material = _overlay_material
	canvas.add_child(overlay)

	_apply_style()

func _apply_style() -> void:
	_overlay_material.set_shader_parameter(&"vignette_color", vignette_color)
	_overlay_material.set_shader_parameter(&"pulse_speed", pulse_speed)
	_overlay_material.set_shader_parameter(&"pulse_amount", pulse_amount)

func _process(delta: float) -> void:
	var stats := Game.stats
	var ratio := stats.hp / maxf(stats.max_hp(), 1.0)

	var target := 0.0
	if ratio < low_hp_threshold:
		target = clampf(1.0 - ratio / low_hp_threshold, 0.0, 1.0)

	_intensity = move_toward(_intensity, target, fade_speed * delta)
	_overlay_material.set_shader_parameter(&"intensity", _intensity)
