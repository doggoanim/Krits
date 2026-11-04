class_name WatercolorEffect
extends Node
## Watercolor look for the whole game, as one full-screen overlay — the same
## bolt-on pattern as PixelateEffect (a CanvasLayer + a ColorRect running
## shading/watercolor_overlay.gdshader over the already-rendered frame).
##
## Shares PixelateEffect's canvas layer and is added to Main just BEFORE it, so
## the painting is made first and any pixelation then mosaics over it; both
## sit below the HUD, which stays crisp. Off by default: the player's Settings
## "display/watercolor" (0-100, percent) sets how strongly it applies — at 0 the
## whole full-screen pass is skipped, so it costs nothing.
##
## Tweak the look itself (wobble, paper, edge pooling...) via the shader's own
## uniforms: set them in `look` below or on the material at runtime.

const CANVAS_LAYER := -9   ## same layer as PixelateEffect; tree order puts this one underneath it

## Overrides for shader uniforms, e.g. {&"paper_strength": 0.6}. See the shader.
@export var look: Dictionary = {}

var _material: ShaderMaterial
var _overlay: ColorRect

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = CANVAS_LAYER
	add_child(canvas)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shading/watercolor_overlay.gdshader")
	for uniform_name: StringName in look:
		_material.set_shader_parameter(uniform_name, look[uniform_name])
	_overlay.material = _material
	canvas.add_child(_overlay)

	Settings.changed.connect(_on_setting_changed)
	_apply(float(Settings.get_value(&"display/watercolor")))

func _on_setting_changed(key: StringName) -> void:
	if key == &"display/watercolor":
		_apply(float(Settings.get_value(key)))

## `percent` 0 = off, 100 = full strength.
func _apply(percent: float) -> void:
	var strength := clampf(percent / 100.0, 0.0, 1.0)
	_material.set_shader_parameter(&"strength", strength)
	_overlay.visible = strength > 0.0   # skip the full-screen pass entirely when off

## For debug tools / other code: same as the Settings value.
func set_strength_percent(percent: float) -> void:
	if _material != null:
		_apply(percent)
