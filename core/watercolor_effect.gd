class_name WatercolorEffect
extends Node
## Watercolor look for the whole game, as one full-screen overlay — the same
## bolt-on pattern as PixelateEffect (a CanvasLayer + a ColorRect running
## shading/watercolor_overlay.gdshader over the already-rendered frame).
##
## Always on, at the "light" strength — it's part of the game's look, not a
## player setting. Shares PixelateEffect's canvas layer and is added to Main
## just BEFORE it, so the painting is made first and any pixelation then
## mosaics over it; both sit below the HUD, which stays crisp.
##
## Tweak the look itself (wobble, paper, edge pooling...) via the shader's own
## uniforms: set them in `look` below, or change STRENGTH.

const CANVAS_LAYER := -9   ## same layer as PixelateEffect; tree order puts this one underneath it
const STRENGTH := 0.75     ## 0 = none, 1 = full painting (the old "Light" preset)

## Overrides for shader uniforms, e.g. {&"paper_strength": 0.6}. See the shader.
## Defaults aim at a clean Wind Waker-style storybook look: soft flat color
## washes with thin painted edges, and almost no grain, wobble or paper — the
## filter should read as "hand-painted", never as camera noise.
@export var look: Dictionary = {
	&"wobble_pixels": 1.4,        # edges wander like brush lines
	&"boil_amount": 0.1,
	&"blur_radius": 1.8,          # soft wash
	&"flatten": 0.55,             # colours snap to flat pigment steps
	&"saturation": 1.0,
	&"granulation": 0.0,          # no pigment grain
	&"paper_strength": 0.0,       # no paper texture
	&"edge_strength": 0.6,        # pigment pooling at shape borders
	&"highlight_lift": 0.0,       # don't fade highlights to paper
	&"highlight_start": 0.85,
	&"green_warm": 0.12,          # neon green -> softer yellow-green
	&"green_desat": 0.1,
}

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = CANVAS_LAYER
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shading/watercolor_overlay.gdshader")
	material.set_shader_parameter(&"strength", STRENGTH)
	for uniform_name: StringName in look:
		material.set_shader_parameter(uniform_name, look[uniform_name])
	overlay.material = material
	canvas.add_child(overlay)
