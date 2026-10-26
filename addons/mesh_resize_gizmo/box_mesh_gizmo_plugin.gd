@tool
extends EditorNode3DGizmoPlugin
## Gives any MeshInstance3D three drag handles in the 3D viewport — one per
## axis — for resizing it by dragging a face, the same way Godot's built-in
## gizmo already lets you drag-resize a CollisionShape3D's BoxShape3D. Each
## handle sits on the mesh's positive face along that axis; dragging it
## extends ONLY that face outward (and pulls it back in) while the opposite
## face stays anchored exactly where it was — like resizing a box in Blender
## by dragging one face.
##
## Two meshes need two different mechanisms to actually "resize", so this
## picks the applicable one per node, both driven through the same shared
## drag/anchor math (_get_local_bounds, _set_handle):
## - BoxMesh: has a real geometric `size`, so that's mutated directly — the
##   Inspector's Mesh > Size field updates live, exactly as before.
## - Anything else (an ArrayMesh from an imported .glb, a PlaneMesh/
##   CylinderMesh/..., anything with no "size" property at all): the mesh's
##   own geometry can't be resized, so the MeshInstance3D's `scale` is
##   adjusted instead, using the mesh's own local-space AABB (Mesh.get_aabb())
##   as the fixed reference bounds. Visually identical drag behavior either
##   way; only what gets written to differs.
##
## For a MeshInstance3D buried inside an instanced glb scene, Godot can't
## select it directly until "Editable Children" is turned on for that
## instance (right-click it in the scene tree) — same as editing any other
## property on an imported scene's internal nodes.
##
## Registered by plugin.gd — not meant to be used standalone.

const LINE_COLOR := Color(1.0, 0.6, 0.0, 0.5)
const MIN_SIZE := 0.02   ## never let a drag collapse an axis to zero/negative

var _undo_redo: EditorUndoRedoManager

## Snapshotted once at the start of the current drag (see _get_handle_value)
## and used for every _set_handle call during it, rather than re-reading the
## node's live, already-moving transform each frame — the far face has to
## stay anchored relative to where the drag STARTED, not wherever it's
## drifted to a few frames in, or the anchor would creep.
var _drag_start_position := Vector3.ZERO
var _drag_start_basis := Basis.IDENTITY
var _drag_start_scale := Vector3.ONE
var _drag_start_bounds := AABB()   ## local-space (pre-scale) min/size, see _get_local_bounds
var _drag_is_box := false

func _init(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo
	create_material(&"mesh_resize_lines", LINE_COLOR)
	create_handle_material(&"mesh_resize_handles", true)

func _get_gizmo_name() -> String:
	return "MeshResize"

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is MeshInstance3D and (for_node_3d as MeshInstance3D).mesh != null

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var mi := gizmo.get_node_3d() as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var bounds := _get_local_bounds(mi.mesh)

	var lines := PackedVector3Array()
	_append_box_wireframe(lines, bounds)
	gizmo.add_lines(lines, get_material(&"mesh_resize_lines", gizmo), false)

	# One handle per axis, centered on the other two axes and sitting on this
	# axis's own positive (max) face. handle_id 0/1/2 = X/Y/Z throughout this
	# whole file — keep them in that order.
	var center := bounds.position + bounds.size * 0.5
	var handles := PackedVector3Array()
	for axis in range(3):
		var p := center
		p[axis] = bounds.position[axis] + bounds.size[axis]
		handles.append(p)
	gizmo.add_handles(handles, get_material(&"mesh_resize_handles", gizmo), PackedInt32Array())

func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return ["Size X", "Size Y", "Size Z"][handle_id]

func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	var mi := gizmo.get_node_3d() as MeshInstance3D
	_drag_start_position = mi.position
	_drag_start_basis = mi.global_transform.basis
	_drag_start_scale = mi.scale
	_drag_start_bounds = _get_local_bounds(mi.mesh)
	_drag_is_box = mi.mesh is BoxMesh
	# Bundles every property either path can change — simplest thing that's
	# still enough to fully restore on cancel/undo (see _commit_handle).
	var box_size := (mi.mesh as BoxMesh).size if _drag_is_box else Vector3.ZERO
	return {"position": mi.position, "scale": mi.scale, "size": box_size}

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var mi := gizmo.get_node_3d() as MeshInstance3D
	if mi == null or mi.mesh == null:
		return

	# Shared by both paths: where the drag-start anchor/dragged faces sit in
	# WORLD space, measured along the axis from the drag-start origin — all
	# computed fresh from the drag-start snapshot every call, never from the
	# node's current (already-moved) state, so the anchor can't creep.
	var axis_world: Vector3 = _drag_start_basis * _unit_axis(handle_id)
	var axis_world_unit := axis_world.normalized()
	var start_center_world := _parent_relative_to_world(mi, _drag_start_position)

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var closest_world := _closest_point_on_line_to_ray(start_center_world, axis_world, ray_origin, ray_dir)
	var dragged_face_offset := (closest_world - start_center_world).dot(axis_world_unit)

	if _drag_is_box:
		# BoxMesh: the anchor/dragged faces ARE the geometry itself (size is
		# mutable), so their offsets are just ±half the drag-start size —
		# same math as before this file supported other mesh types too.
		var start_half: float = _drag_start_bounds.size[handle_id] * 0.5
		var anchor_face_offset := -start_half
		dragged_face_offset = maxf(dragged_face_offset, anchor_face_offset + MIN_SIZE)

		var new_axis_size := dragged_face_offset - anchor_face_offset
		var center_shift := (dragged_face_offset + anchor_face_offset) * 0.5

		var box := mi.mesh as BoxMesh
		var new_size := box.size
		new_size[handle_id] = new_axis_size
		box.size = new_size
		mi.global_position = start_center_world + axis_world_unit * center_shift
	else:
		# Any other mesh: geometry is fixed (Mesh.get_aabb(), captured once
		# at drag-start in _drag_start_bounds), so the anchor/dragged faces
		# are that fixed local extent scaled by the drag-start scale —
		# solving for a NEW scale (and the position shift that keeps the
		# anchor face fixed) instead of a new size. See this file's header
		# comment for why.
		var aabb_min: float = _drag_start_bounds.position[handle_id]
		var aabb_max: float = aabb_min + _drag_start_bounds.size[handle_id]
		var local_extent := aabb_max - aabb_min
		if absf(local_extent) < 0.0001:
			return   ## degenerate mesh (zero thickness on this axis) — nothing sensible to drag

		var anchor_face_offset := aabb_min * _drag_start_scale[handle_id]
		dragged_face_offset = maxf(dragged_face_offset, anchor_face_offset + MIN_SIZE)

		var new_scale_axis := (dragged_face_offset - anchor_face_offset) / local_extent
		var origin_shift := anchor_face_offset - aabb_min * new_scale_axis

		var new_scale := mi.scale
		new_scale[handle_id] = new_scale_axis
		mi.scale = new_scale
		mi.global_position = start_center_world + axis_world_unit * origin_shift

func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var mi := gizmo.get_node_3d() as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	if cancel:
		mi.position = restore.position
		if _drag_is_box:
			(mi.mesh as BoxMesh).size = restore.size
		else:
			mi.scale = restore.scale
		return

	_undo_redo.create_action("Resize Mesh")
	_undo_redo.add_do_property(mi, &"position", mi.position)
	_undo_redo.add_undo_property(mi, &"position", restore.position)
	if _drag_is_box:
		var box := mi.mesh as BoxMesh
		_undo_redo.add_do_property(box, &"size", box.size)
		_undo_redo.add_undo_property(box, &"size", restore.size)
	else:
		_undo_redo.add_do_property(mi, &"scale", mi.scale)
		_undo_redo.add_undo_property(mi, &"scale", restore.scale)
	_undo_redo.commit_action(false)   ## false: the live edit already applied the do-values, don't reapply

## The fixed (pre-scale, local/object-space) bounds a drag's anchor/dragged
## faces are measured against. For a BoxMesh this mirrors its own mutable
## `size` (centered on the origin, same convention as before); for anything
## else it's the mesh's own geometric AABB, whatever that actually is —
## most imported meshes (a tree, a character) are NOT centered on their own
## origin (a tree's origin usually sits at its base, not its middle), and
## that's fine: the anchor/dragged math below works of whatever bounds.
## position/size this returns, with no assumption that they straddle zero.
func _get_local_bounds(mesh: Mesh) -> AABB:
	if mesh is BoxMesh:
		var half: Vector3 = (mesh as BoxMesh).size * 0.5
		return AABB(-half, (mesh as BoxMesh).size)
	return mesh.get_aabb()

## `local_position` (e.g. _drag_start_position, a Node3D's local `position`)
## converted to world space via the node's PARENT's current global transform
## — not the node's own, since by the time this is called mid-drag the
## node's own transform has already moved away from where the drag started.
func _parent_relative_to_world(mi: Node3D, local_position: Vector3) -> Vector3:
	var parent := mi.get_parent_node_3d()
	return parent.global_transform * local_position if parent else local_position

func _unit_axis(handle_id: int) -> Vector3:
	var axis := Vector3.ZERO
	axis[handle_id] = 1.0
	return axis

func _append_box_wireframe(lines: PackedVector3Array, bounds: AABB) -> void:
	var corners: Array[Vector3] = []
	for sx in [0.0, 1.0]:
		for sy in [0.0, 1.0]:
			for sz in [0.0, 1.0]:
				corners.append(bounds.position + bounds.size * Vector3(sx, sy, sz))
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
