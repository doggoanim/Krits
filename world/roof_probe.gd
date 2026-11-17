class_name RoofProbe
extends RefCounted
## Reads a house's roof from its own triangles: how high the roof surface is at a spot
## and which way it slopes there, so things (a chimney, a dormer, a weathervane) can stand
## on it wherever the house is and whatever its shape. Everything is in the house's own
## space. Works on any mesh surface whose material is called "roof" (the house models').

const COLLISION_NAME := "collision"   ## helper meshes under this name are not the visible roof

## {y, normal} of the highest roof triangle covering (x, z) seen from above, or an
## empty Dictionary when there is no roof there.
static func sample(house: Node3D, xz: Vector2) -> Dictionary:
	var best := {}
	var inverse := house.global_transform.affine_inverse()
	for m in house.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or String(mi.name).containsn(COLLISION_NAME):
			continue
		var to_house := inverse * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(surface)
			if mat == null or not mat.resource_name.to_lower().contains("roof"):
				continue
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var count: int = (indices.size() if indices != null else verts.size())
			for t in range(0, count - 2, 3):
				var a := to_house * verts[indices[t] if indices != null else t]
				var b := to_house * verts[indices[t + 1] if indices != null else t + 1]
				var c := to_house * verts[indices[t + 2] if indices != null else t + 2]
				var y := _height_in_triangle(xz, a, b, c)
				if is_nan(y) or (not best.is_empty() and y <= float(best["y"])):
					continue
				var n := (b - a).cross(c - a).normalized()
				best = {"y": y, "normal": n if n.y >= 0.0 else -n}
	return best

## The roof's highest point near `xz` (searching a small grid): where a weathervane goes.
static func ridge(house: Node3D, xz: Vector2, reach := 1.5) -> Dictionary:
	var best := {}
	for dx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for dz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var s := sample(house, xz + Vector2(dx, dz) * reach)
			if not s.is_empty() and (best.is_empty() or float(s["y"]) > float(best["y"])):
				best = s
				best["x"] = xz.x + dx * reach
				best["z"] = xz.y + dz * reach
	return best

## z of the front wall (the "wall" material, +Z side) around x, at door height, in the
## house's own space; NAN when there is none. Used to put a door canopy flush on the wall.
static func wall_front(house: Node3D, x: float, half_width := 1.5, y_low := 0.3, y_high := 2.5) -> float:
	var best := NAN
	var inverse := house.global_transform.affine_inverse()
	for m in house.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or String(mi.name).containsn(COLLISION_NAME):
			continue
		var to_house := inverse * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(surface)
			if mat == null or not mat.resource_name.to_lower().contains("wall"):
				continue
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p := to_house * v
				if absf(p.x - x) <= half_width and p.y > y_low and p.y < y_high and (is_nan(best) or p.z > best):
					best = p.z
	return best

## The height of triangle (a, b, c)'s plane at xz, or NAN if xz is outside it (seen from above).
static func _height_in_triangle(xz: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(xz.x - a.x, xz.y - a.z)
	var denom := v0.x * v1.y - v1.x * v0.y
	if absf(denom) < 0.00001:
		return NAN
	var u := (v2.x * v1.y - v1.x * v2.y) / denom
	var v := (v0.x * v2.y - v2.x * v0.y) / denom
	if u < 0.0 or v < 0.0 or u + v > 1.0:
		return NAN
	return a.y + u * (b.y - a.y) + v * (c.y - a.y)
