class_name LowPoly
extends RefCounted
## Builders for flat-shaded, slightly irregular meshes — chunky hand-modelled
## crystals instead of smooth primitives. Every face gets its own
## normal (so facets read as flat planes), a vertex colour, and planar UVs.
## The same `seed_value` always gives the same shape.

const UV_SCALE := 0.6

## A faceted crystal standing on its base: pointed bottom, a `sides`-sided
## shaft `body` tall that tapers a little, and a pointed top. Origin = the
## widest ring (the "waist"), +Y up.
static func crystal(radius: float, body: float, tip_top: float, tip_bottom: float,
		sides := 6, seed_value := 1, color := Color.WHITE) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var waist: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	for i in sides:
		var a := TAU * float(i) / sides + rng.randf_range(-0.12, 0.12)
		var r0 := radius * rng.randf_range(0.88, 1.08)
		var r1 := radius * 0.82 * rng.randf_range(0.9, 1.08)
		waist.append(Vector3(cos(a) * r0, 0.0, sin(a) * r0))
		shoulder.append(Vector3(cos(a + 0.15) * r1, body * rng.randf_range(0.92, 1.08), sin(a + 0.15) * r1))
	var top := Vector3(rng.randf_range(-0.04, 0.04), body + tip_top, rng.randf_range(-0.04, 0.04))
	var bottom := Vector3(rng.randf_range(-0.03, 0.03), -tip_bottom, rng.randf_range(-0.03, 0.03))
	var centre := Vector3(0.0, body * 0.5, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var j := (i + 1) % sides
		_tri(st, bottom, waist[j], waist[i], centre, color)
		_quad(st, waist[i], waist[j], shoulder[j], shoulder[i], centre, color)
		_tri(st, shoulder[i], shoulder[j], top, centre, color)
	return st.commit()

## Outward-facing normal of triangle (a, b, c) for a body centred on `centre`.
## Godot treats clockwise winding as front, so (c - a) x (b - a) points out of
## a clockwise face; flipped if the triangle was wound the other way.
static func _face_normal(a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> Vector3:
	var n := (c - a).cross(b - a).normalized()
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		n = -n
	return n

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3, color: Color) -> void:
	var n := _face_normal(a, b, c, centre)
	var flip := (c - a).cross(b - a).normalized().dot(n) < 0.0
	var pts := [a, c, b] if flip else [a, b, c]
	for p in pts:
		st.set_normal(n)
		st.set_color(color)
		st.set_uv(Vector2(p.x + p.z * 0.5, p.y + p.z * 0.5) * UV_SCALE)
		st.add_vertex(p)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, centre: Vector3, color: Color) -> void:
	_tri(st, a, b, c, centre, color)
	_tri(st, a, c, d, centre, color)
