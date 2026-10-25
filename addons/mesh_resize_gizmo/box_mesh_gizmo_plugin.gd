@tool
extends EditorNode3DGizmoPlugin
## Gives any MeshInstance3D whose mesh is a BoxMesh three drag handles in the
## 3D viewport — one per axis — that resize mesh.size directly, the same way
## Godot's built-in gizmo already lets you drag-resize a CollisionShape3D's
## BoxShape3D. Each handle sits on one of the box's positive faces and moves
## along that axis only; dragging it resizes the box symmetrically about its
## own center (same convention the built-in BoxShape3D gizmo uses), rather
## than anchoring one face and growing away from it.
##
## Multi-select: if other MeshInstance3D/BoxMesh nodes are selected alongside
## the one whose handle you actually drag, they're resized too — to the same
## final size on that axis (matching how Godot's own Inspector multi-edit
## behaves when you change one shared numeric field with several nodes
## selected), not by the same relative delta. See _get_handle_value (where
## the group snapshot is taken, once per drag) and _group_originals.
##
## Registered by plugin.gd — not meant to be used standalone.

const HANDLE_COLOR := Color(1.0, 0.6, 0.0)
const LINE_COLOR := Color(1.0, 0.6, 0.0, 0.5)
const MIN_HALF_SIZE := 0.01   ## never let a drag collapse an axis to zero/negative

var _undo_redo: EditorUndoRedoManager

## Other selected boxes being dragged along with the one the handle actually
## belongs to, captured once at the start of the current drag (see
## _get_handle_value) — MeshInstance3D -> its BoxMesh's original size, so
## _commit_handle can both finalize and build one combined undo action, and
## cancel can restore everyone, not just the primary node.
var _group_originals: Dictionary = {}

func _init(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo
	create_material(&"mesh_resize_lines", LINE_COLOR)
	create_handle_material(&"mesh_resize_handles", true)

func _get_gizmo_name() -> String:
	return "BoxMeshResize"

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is MeshInstance3D and (for_node_3d as MeshInstance3D).mesh is BoxMesh

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var box := _get_box(gizmo)
	if box == null:
		return
	var half := box.size * 0.5

	var lines := PackedVector3Array()
	_append_box_wireframe(lines, half)
	gizmo.add_lines(lines, get_material(&"mesh_resize_lines", gizmo), false)

	# One handle per axis, sitting on that axis's positive face. handle_id
	# 0/1/2 = X/Y/Z throughout this whole file — keep them in that order.
	gizmo.add_handles(
		PackedVector3Array([Vector3(half.x, 0.0, 0.0), Vector3(0.0, half.y, 0.0), Vector3(0.0, 0.0, half.z)]),
		get_material(&"mesh_resize_handles", gizmo),
		PackedInt32Array())

func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return ["Size X", "Size Y", "Size Z"][handle_id]

func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	# Called exactly once per drag, right as it starts — the right moment to
	# snapshot every OTHER selected box too, so a multi-selected drag has
	# something to restore on cancel and something to diff against for the
	# combined undo action in _commit_handle.
	var mi := gizmo.get_node_3d() as MeshInstance3D
	_group_originals.clear()
	for node in EditorInterface.get_selection().get_selected_nodes():
		if node != mi and node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
			_group_originals[node] = (node.mesh as BoxMesh).size

	# Returns the whole size, not just the one axis — simplest thing that's
	# still enough to fully restore on cancel/undo (see _commit_handle).
	return _get_box(gizmo).size

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var box := _get_box(gizmo)
	if box == null:
		return
	var mi := gizmo.get_node_3d() as MeshInstance3D
	var gt := mi.global_transform

	var axis := Vector3.ZERO
	axis[handle_id] = 1.0
	var axis_world := gt.basis * axis
	var center_world := gt.origin

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var closest_world := _closest_point_on_line_to_ray(center_world, axis_world, ray_origin, ray_dir)
	var closest_local: Vector3 = gt.affine_inverse() * closest_world

	var new_axis_size := maxf(MIN_HALF_SIZE, absf(closest_local[handle_id])) * 2.0
	var new_size := box.size
	new_size[handle_id] = new_axis_size
	box.size = new_size

	# Same final size on this axis for every other selected box, live during
	# the drag — update_gizmos() forces each one's own gizmo to redraw
	# immediately instead of waiting for whatever would normally mark it dirty.
	for node: MeshInstance3D in _group_originals:
		var other_box := node.mesh as BoxMesh
		var other_size := other_box.size
		other_size[handle_id] = new_axis_size
		other_box.size = other_size
		node.update_gizmos()

func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var box := _get_box(gizmo)
	if box == null:
		return
	if cancel:
		box.size = restore
		for node: MeshInstance3D in _group_originals:
			(node.mesh as BoxMesh).size = _group_originals[node]
			node.update_gizmos()
		_group_originals.clear()
		return

	var final_size: Vector3 = box.size
	var action_name := "Resize BoxMesh" if _group_originals.is_empty() else \
			"Resize BoxMesh (%d selected)" % (_group_originals.size() + 1)
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_property(box, &"size", final_size)
	_undo_redo.add_undo_property(box, &"size", restore)
	for node: MeshInstance3D in _group_originals:
		var other_box := node.mesh as BoxMesh
		_undo_redo.add_do_property(other_box, &"size", other_box.size)
		_undo_redo.add_undo_property(other_box, &"size", _group_originals[node])
	_undo_redo.commit_action(false)   ## false: the live edit already applied the do-values, don't reapply
	_group_originals.clear()

func _get_box(gizmo: EditorNode3DGizmo) -> BoxMesh:
	var mi := gizmo.get_node_3d() as MeshInstance3D
	return mi.mesh as BoxMesh if mi else null

func _append_box_wireframe(lines: PackedVector3Array, half: Vector3) -> void:
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(Vector3(half.x * sx, half.y * sy, half.z * sz))
	# Index into `corners` as a binary count (sx,sy,sz each 0/1 -> 0..7); the
	# 12 standard box edges as pairs of corners one bit apart.
	const EDGES := [
		[0, 1], [0, 2], [0, 4], [3, 1], [3, 2], [3, 7],
		[5, 1], [5, 4], [5, 7], [6, 2], [6, 4], [6, 7],
	]
	for edge in EDGES:
		lines.append(corners[edge[0]])
		lines.append(corners[edge[1]])

## Closest point to `ray_origin + t * ray_dir` on the infinite line through
## `line_origin` along `line_dir` — the standard closest-point-between-two-
## skew-lines formula. This is how dragging a handle in 2D screen space
## (the mouse ray from the camera) turns into a 1D distance along the
## handle's own 3D axis.
func _closest_point_on_line_to_ray(line_origin: Vector3, line_dir: Vector3, ray_origin: Vector3, ray_dir: Vector3) -> Vector3:
	line_dir = line_dir.normalized()
	ray_dir = ray_dir.normalized()
	var w0 := line_origin - ray_origin
	var b := line_dir.dot(ray_dir)
	var d := line_dir.dot(w0)
	var e := ray_dir.dot(w0)
	var denom := 1.0 - b * b   ## a = c = 1 since both directions are normalized
	var t := (b * e - d) / denom if absf(denom) > 1e-6 else 0.0
	return line_origin + line_dir * t
