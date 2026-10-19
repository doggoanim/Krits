class_name SoftCircleTexture
extends RefCounted
## A soft white circle fading to transparent at the edge, built with a radial
## GradientTexture2D instead of an image file. Shared by anything that wants
## a simple round sprite — dust/smoke particles (PlayerEffects), the ground
## depth-perception marker (GroundShadow), etc.

static func make(size := 32) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
