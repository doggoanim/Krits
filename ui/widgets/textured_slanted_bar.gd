class_name TexturedSlantedBar
extends Control
## Like SlantedBar, but reveals a hand-painted texture instead of a flat
## fill color — used once real art (assets/ui/*.png, cropped from the
## designer's mockup) replaced the HP/shield/stamina placeholders. Same
## reveal geometry as SlantedBar (skew = 0 gives a plain rectangle, used for
## Stamina), but instead of drawing a solid polygon, it UV-maps `texture`
## onto that polygon so only the fraction of the art up to `value` shows —
## the art's own right edge gets cut off as the bar drains, same as a flat
## color would, just painted instead of flat. The shield frame uses this too:
## its texture is just the border strokes with a transparent interior (see
## assets/ui/shield_frame.png), so "revealing" it still looks like an
## outline, not a filled shape.

@export var texture: Texture2D
@export var skew := 0.0

var max_value := 1.0:
	set(v):
		max_value = maxf(v, 0.0)
		queue_redraw()

var value := 1.0:
	set(v):
		value = clampf(v, 0.0, max_value)
		queue_redraw()

func _draw() -> void:
	if texture == null or max_value <= 0.0 or value <= 0.0:
		return
	var frac := value / max_value
	var w := size.x * frac
	var h := size.y
	var points := PackedVector2Array([
		Vector2(skew, 0.0),
		Vector2(skew + w, 0.0),
		Vector2(w, h),
		Vector2(0.0, h),
	])
	# UV x goes 0..frac — the texture's own left portion, the same fraction as
	# the polygon's width. That's what makes the art drain from the right as
	# value drops, instead of squashing/stretching the whole image to fit.
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(frac, 0.0),
		Vector2(frac, 1.0),
		Vector2(0.0, 1.0),
	])
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)
