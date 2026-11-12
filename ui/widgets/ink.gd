class_name Ink
extends RefCounted
## Helpers for drawing hand-inked shapes in code: lines that wobble a little
## instead of being ruler-straight, to match the hand-drawn UI plates.

const INK := Color(0.05, 0.05, 0.07)

## `points` with every edge split into `steps` pieces, each nudged by up to
## `amp` pixels. The same `seed_value` always gives the same wobble, so a
## shape stays put between frames; change it over time for a "boiling line"
## stop-motion look.
static func wobble(points: PackedVector2Array, seed_value: int, amp := 1.6, steps := 4) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			if s > 0:   # keep the corners where they are
				p += Vector2(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp))
			out.append(p)
	out.append(points[points.size() - 1])
	return out

## A closed outline: `points` with the first point repeated at the end.
static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out

## A wavy horizontal line from `from` to `to`, `waves` bumps of height `amp`.
static func squiggle(from: Vector2, to: Vector2, waves: int, amp: float, samples := 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in samples + 1:
		var t := float(i) / samples
		out.append(from.lerp(to, t) + Vector2(0.0, sin(t * TAU * waves) * amp))
	return out
