class_name SlantedBar
extends Control
## A parallelogram-shaped meter: the top edge is horizontally offset from the
## bottom edge by `skew` pixels, so `skew = 0.0` draws a plain rectangle (used
## for the Stamina bar) and `skew > 0.0` gives the slanted look used for the
## HP bar and its shield frame.
##
## Two draw modes, picked per instance so several of these can be stacked on
## the same rect to build a layered meter (see Hud._build_meter_cluster):
##   - solid fill (outline_only = false): a colored polygon sized to `value`,
##     used for the HP/Stamina track (background) and fill (foreground).
##   - outline only (outline_only = true): just the border, used for the
##     shield frame. It shares the HP bar's rect and skew, so as shield drains
##     its right edge draws inward — the border "burns down" from right to
##     left rather than fading out.

@export var skew := 0.0
@export var fill_color := Color.WHITE
@export var outline_only := false
@export var outline_width := 3.0

var max_value := 1.0:
	set(v):
		max_value = maxf(v, 0.0)
		queue_redraw()

var value := 1.0:
	set(v):
		value = clampf(v, 0.0, max_value)
		queue_redraw()

func _draw() -> void:
	if max_value <= 0.0 or value <= 0.0:
		return
	var frac := value / max_value
	var w := size.x * frac
	var h := size.y
	# Top edge spans [skew, skew + w], bottom edge spans [0, w]: both edges
	# keep the same width (and so the same skew angle) as the bar drains,
	# it's just a narrower copy of the full shape rather than a crop of it.
	var points := PackedVector2Array([
		Vector2(skew, 0.0),
		Vector2(skew + w, 0.0),
		Vector2(w, h),
		Vector2(0.0, h),
	])
	if outline_only:
		draw_polyline(
			PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
			fill_color, outline_width, true)
	else:
		draw_colored_polygon(points, fill_color)
