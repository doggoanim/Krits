class_name MeshUtil
extends RefCounted
## Small procedural-mesh helpers that don't belong to any one system. Grows
## here if more procedural shapes are needed later; currently just the
## hexagon plane used by world/water/water_hex_shape.gd.

## Builds a flat, radially-subdivided hexagonal mesh centered at the origin,
## lying in the XZ plane (Y = 0) — a drop-in alternative to PlaneMesh for
## anything (like water.gdshader's per-vertex wave displacement) that expects
## enough vertex density to look smooth rather than faceted.
##
## Built as 6 triangular wedges (center -> each pair of adjacent hexagon
## corners), each subdivided into a regular triangular grid and welded
## together along shared edges — a single flat-shaded hexagon (6 big
## triangles, subdivisions = 1) would show visible creases under any kind of
## per-vertex displacement, since each triangle is flat between its corners.
##
## `radius`: center-to-corner distance. `subdivisions`: triangle rows per
## wedge edge — higher is smoother geometry but more vertices
## (6 * subdivisions^2 triangles total). 1 gives a plain flat hexagon with no
## interior vertices.
static func hexagon_plane(radius: float, subdivisions: int = 6) -> ArrayMesh:
	var n := maxi(1, subdivisions)
	var verts: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var indices: Array[int] = []
	# Welds vertices shared between adjacent wedges (the center, and each
	# center-to-corner edge) so the result is one seamless surface rather
	# than 6 independent triangle fans that merely happen to touch.
	var welded := {}   ## Vector3 (rounded) -> int index

	var corners: Array[Vector3] = []
	for k in range(6):
		var angle := deg_to_rad(60.0 * k)
		corners.append(Vector3(cos(angle), 0.0, sin(angle)) * radius)

	var center := Vector3.ZERO
	for k in range(6):
		_subdivide_wedge(center, corners[k], corners[(k + 1) % 6], n, radius,
				verts, normals, uvs, indices, welded)

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## One wedge is the triangle (center, a, b), subdivided into an n x n
## triangular grid via standard barycentric subdivision:
## point(i, j) = center + (a - center) * i/n + (b - center) * j/n, for all
## integer i, j >= 0 with i + j <= n.
static func _subdivide_wedge(center: Vector3, a: Vector3, b: Vector3, n: int, uv_radius: float,
		verts: Array[Vector3], normals: Array[Vector3], uvs: Array[Vector2],
		indices: Array[int], welded: Dictionary) -> void:
	var grid: Array = []   ## grid[i][j] -> vertex index, for i in 0..n, j in 0..(n - i)
	for i in range(n + 1):
		var row: Array[int] = []
		for j in range(n + 1 - i):
			var u := float(i) / float(n)
			var v := float(j) / float(n)
			var pos := center + (a - center) * u + (b - center) * v
			row.append(_weld_vertex(pos, uv_radius, verts, normals, uvs, welded))
		grid.append(row)

	for i in range(n):
		for j in range(n - i):
			var p00: int = grid[i][j]
			var p10: int = grid[i + 1][j]
			var p01: int = grid[i][j + 1]
			indices.append(p00)
			indices.append(p10)
			indices.append(p01)
			if i + j < n - 1:
				var p11: int = grid[i + 1][j + 1]
				indices.append(p10)
				indices.append(p11)
				indices.append(p01)

static func _weld_vertex(pos: Vector3, uv_radius: float, verts: Array[Vector3],
		normals: Array[Vector3], uvs: Array[Vector2], welded: Dictionary) -> int:
	# Round off to kill float-precision mismatches between wedges computing
	# the same shared-edge point via different (center, a, b) triples.
	var key := Vector3(snappedf(pos.x, 0.0001), snappedf(pos.y, 0.0001), snappedf(pos.z, 0.0001))
	if welded.has(key):
		return welded[key]
	var idx := verts.size()
	verts.append(pos)
	normals.append(Vector3.UP)
	uvs.append(Vector2(pos.x / (uv_radius * 2.0) + 0.5, pos.z / (uv_radius * 2.0) + 0.5))
	welded[key] = idx
	return idx
