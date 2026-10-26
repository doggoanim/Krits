@tool
extends EditorNode3DGizmoPlugin
## Gives any MeshInstance3D whose mesh is a BoxMesh three drag handles in the
## 3D viewport — one per axis — that resize mesh.size directly, the same way
## Godot's built-in gizmo already lets you drag-resize a CollisionShape3D's
## BoxShape3D. Each handle sits on one of the box's positive faces; dragging
## it extends ONLY that face outward (and pulls it back in) while the
## opposite face stays anchored exactly where it was — like resizing a box in
## Blender by dragging one face, not Godot's own symmetric BoxShape3D gizmo
## convention. Since BoxMesh itself always centers on the node's own origin,
## keeping the far face fixed in world space means this moves the node
## (position) and resizes the mesh together every frame — see _set_handle.
##
## Registered by plugin.gd — not meant to be used standalone.

const LINE_COLOR := Color(1.0, 0.6, 0.0, 0.5)
const MIN_SIZE := 0.02   ## never let a drag collapse an axis to zero/negative

var _undo_redo: EditorUndoRedoManager

## Snapshotted once at the start of the current drag (see _get_handle_value)
## and used for every _set_handle call during it, rather than re-reading the
## node's live, already-moving transform each frame — the far face has to
## stay anchored relative to where the box STARTED, not wherever it's
## drifted to a few frames into the drag, or the anchor would creep.
var _drag_start_position := Vector3.ZERO
var _drag_start_basis := Basis.IDENTITY
var _drag_start_size := Vector3.ZERO

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
	var mi := gizmo.get_node_3d() as MeshInstance3D
	var box := _get_box(gizmo)
	_drag_start_position = mi.position
	_drag_start_basis = mi.global_transform.basis
	_drag_start_size = box.size
	# Bundles both properties this drag can change — simplest thing that's
	# still enough to fully restore on cancel/undo (see _commit_handle).
	return {"position": mi.position, "size": box.size}

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var box := _get_box(gizmo)
	if box == null:
		return
	var mi := gizmo.get_node_3d() as MeshInstance3D

	# All of this is computed fresh from the drag-start snapshot every call,
	# never from the node's current (already-moved) state — see this file's
	# header comment and _drag_start_* for why.
	var start_half: float = _drag_start_size[handle_id] * 0.5
	var axis_world: Vector3 = _drag_start_basis * _unit_axis(handle_id)
	var anchor_face_offset := -start_half   ## the far face, fixed throughout the drag
	var start_center_world: Vector3 = mi.get_parent_node_3d().global_transform * _drag_start_position \
			if mi.get_parent_node_3d() else _drag_start_position

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var closest_world := _closest_point_on_line_to_ray(start_center_world, axis_world, ray_origin, ray_dir)
	var dragged_face_offset := (closest_world - start_center_world).dot(axis_world.normalized())
	# Keep the dragged face on its own (positive) side of the anchor, at
	# least MIN_SIZE away from it — this is what stops the box collapsing or
	# flipping inside-out as the drag crosses back past the anchored face.
	dragged_face_offset = maxf(dragged_face_offset, anchor_face_offset + MIN_SIZE)

	var new_axis_size := dragged_face_offset - anchor_face_offset
	var center_shift_along_axis := (dragged_face_offset + anchor_face_offset) * 0.5

	var new_size := _drag_start_size
	new_size[handle_id] = new_axis_size
	box.size = new_size
	mi.global_position = start_center_world + axis_world.normalized() * center_shift_along_axis

func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var box := _get_box(gizmo)
	if box == null:
		return
	var mi := gizmo.get_node_3d() as MeshInstance3D
	if cancel:
		mi.position = restore.position
		box.size = restore.size
		return
	_undo_redo.create_action("Resize BoxMesh")
	_undo_redo.add_do_property(mi, &"position", mi.position)
	_undo_redo.add_undo_property(mi, &"position", restore.position)
	_undo_redo.add_do_property(box, &"size", box.size)
	_undo_redo.add_undo_property(box, &"size", restore.size)
	_undo_redo.commit_action(false)   ## false: the live edit already applied the do-values, don't reapply

func _unit_axis(handle_id: int) -> Vector3:
	var axis := Vector3.ZERO
	axis[handle_id] = 1.0
	return axis

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
