class_name PixelateEffect
extends Node
## Chunky retro-pixel look for the whole game, as one full-screen overlay —
## the same bolt-on pattern OutlineSystem uses (a CanvasLayer + a ColorRect
## running a shader), just reading the already-composited screen via
## SCREEN_TEXTURE instead of a second camera's own render.
##
## Sits ABOVE OutlineSystem's canvas layer (-10) so the character-outline
## ring gets pixelated along with everything else, but BELOW the HUD
## (UiRoot, default CanvasLayer layer 1) so menus and on-screen text stay
## crisp and legible.
##
## Usage: Main creates exactly one of these for the whole game — see
## main.gd. No follow()/setup call needed (unlike OutlineSystem): this reads
## whatever's already on screen, so it doesn't care what camera is active.

const CANVAS_LAYER := -9   ## above OutlineSystem (-10), below the HUD (1) — see header comment

@export var pixel_size := 4.0   ## block size, in real screen pixels — scales with resolution, not window size
                                ## (the player's Settings "display/pixelation" overrides this at startup and live)

var _overlay_material: ShaderMaterial
var _overlay: ColorRect

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = CANVAS_LAYER
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = preload("res://shading/pixelate_overlay.gdshader")
	overlay.material = _overlay_material
	canvas.add_child(overlay)
	_overlay = overlay

	pixel_size = float(Settings.get_value(&"display/pixelation"))
	Settings.changed.connect(_on_setting_changed)
	_apply_style()

func _on_setting_changed(key: StringName) -> void:
	if key == &"display/pixelation":
		set_pixel_size(float(Settings.get_value(key)))

func _apply_style() -> void:
	_overlay_material.set_shader_parameter(&"pixel_size", pixel_size)
	_overlay.visible = pixel_size > 1.0   # 1 = off: skip the full-screen pass entirely

## Lets debug tools or a settings menu change the chunkiness at runtime.
func set_pixel_size(size: float) -> void:
	pixel_size = size
	if _overlay_material != null:
		_apply_style()
