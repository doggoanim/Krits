@tool
extends EditorNode3DGizmoPlugin
## Gives a Node3D six drag handles in the 3D viewport — one per face — for
## resizing it by dragging a face, the same way Godot's built-in gizmo
## already lets you drag-resize a CollisionShape3D's BoxShape3D. Dragging a
## handle extends ONLY that face outward (and pulls it back in) while the
## OPPOSITE face stays anchored exactly where it was — like resizing a box
## in Blender by dragging one face. handle_id 0..5 pairs up as
## (+X,-X,+Y,-Y,+Z,-Z) throughout this file — see HANDLE_AXIS/HANDLE_SIGN.
##
## Applies to two kinds of selection, both driven through the same shared
## drag/anchor math (_get_local_bounds, _set_handle):
## - A lone MeshInstance3D with a BoxMesh: has a real geometric `size`, so
##   that's mutated directly — the Inspector's Mesh > Size field updates
##   live, exactly like the built-in BoxShape3D gizmo does for collision.
## - Anything else with a mesh somewhere in it: a lone MeshInstance3D using
##   any other mesh type, OR the root of an instanced scene (most .glb
##   props — a multi-part model is usually several MeshInstance3D children
##   under one root, which is what you actually select without turning on
##   "Editable Children"). The combined bounds of every MeshInstance3D found
##   inside it (Mesh.get_aabb(), each transformed into the root's own local
##   space) stands in for a fixed "size", and dragging adjusts the whole
##   node's `scale` instead — resizing every part together, proportionally,
##   since scaling the root scales all its children with it. Visually
##   identical drag behavior to the BoxMesh case; only what gets written to
##   differs.
##
## Registered by plugin.gd — not meant to be used standalone.

const LINE_COLOR := Color(1.0, 0.6, 0.0, 0.5)
const HANDLE_COLOR := Color(1.0, 0.6, 0.0, 1.0)
const HANDLE_TEXTURE_SIZE := 24   ## Godot's own default handle dot is tiny (~8px) and easy to
                                   ## miss-click — a bigger custom texture both looks clearer and,
                                   ## since the billboard's hit area is sized off the texture's own
                                   ## pixel dimensions, is noticeably easier to actually grab.
const MIN_SIZE := 0.02   ## never let a drag collapse an axis to zero/negative

## handle_id 0..5 -> which axis (0/1/2 = X/Y/Z) and which face of it (+1 = max
## face, -1 = min face). Every place that used to assume "axis == handle_id"
## and "always the positive face" now goes through these two instead.
const HANDLE_AXIS := [0, 0, 1, 1, 2, 2]
const HANDLE_SIGN := [1.0, -1.0, 1.0, -1.0, 1.0, -1.0]
const HANDLE_NAMES := ["Size +X", "Size -X", "Size +Y", "Size -Y", "Size +Z", "Size -Z"]

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
var _drag_is_box := false          ## true only for a lone MeshInstance3D using a BoxMesh

func _init(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo
	create_material(&"mesh_resize_lines", LINE_COLOR)
	create_handle_material(&"mesh_resize_handles", true, _make_handle_texture())

## A plain filled circle, solid-color with a 1px antialiased edge — built at
## runtime instead of shipped as an image file, same idea as
## core/soft_circle_texture.gd elsewhere in the project, just not reusing
## that one directly: this addon stays self-contained rather than reaching
## into the game's own core/ scripts.
func _make_handle_texture() -> ImageTexture:
	var size := HANDLE_TEXTURE_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var radius := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf(radius + 1.0 - dist, 0.0, 1.0)   ## 1px soft edge, solid inside
			img.set_pixel(x, y, Color(HANDLE_COLOR.r, HANDLE_COLOR.g, HANDLE_COLOR.b, HANDLE_COLOR.a * alpha))
	return ImageTexture.create_from_image(img)

func _get_gizmo_name() -> String:
	return "MeshResize"

func _has_gizmo(for_node_3d: Node3D) -> bool:
	# A mesh part nested inside an already-instanced scene (a wall or roof
	# MeshInstance3D inside a multi-part .glb, say — only reachable at all
	# with "Editable Children" on) defers entirely to that instance's own
	# root gizmo below, rather than also getting its own: without this, a
	# multi-part model shows one gizmo per part PLUS the whole-object one,
	# each sized to that one part's own small edge instead of the model's
	# actual outer bounds — looks like a scattered, inconsistent mess of
	# handles instead of one clean set of 3.
	if for_node_3d.scene_file_path.is_empty() and _has_instanced_ancestor(for_node_3d):
		return false
	if for_node_3d is MeshInstance3D:
		return (for_node_3d as MeshInstance3D).mesh != null
	# A plain organizational Node3D (an empty group like "Props") shouldn't
	# get a giant gizmo spanning everything inside it — only the root of an
	# actual instanced scene (scene_file_path set: a .glb prop, a .tscn
	# instance like water.tscn) with at least one mesh somewhere inside it.
	if for_node_3d.scene_file_path.is_empty():
		return false
	return not _find_mesh_instances(for_node_3d).is_empty()

## True if some ancestor (not `node` itself) is the root of an instanced
## scene — i.e. `node` is one of that instance's own internal nodes, as
## opposed to a standalone node authored directly in the scene being edited.
func _has_instanced_ancestor(node: Node) -> bool:
	var p := node.get_parent()
	while p != null:
		if p is Node3D and not (p as Node3D).scene_file_path.is_empty():
			return true
		p = p.get_parent()
	return false

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	var bounds := _get_local_bounds(node)
	if bounds.size == Vector3.ZERO:
		return

	var lines := PackedVector3Array()
	_append_box_wireframe(lines, bounds)
	gizmo.add_lines(lines, get_material(&"mesh_resize_lines", gizmo), false)

	# One handle per face: handle_id 0..5 -> (axis, sign) via HANDLE_AXIS/
	# HANDLE_SIGN. Each sits centered on the other two axes, on its own face
	# (max face for sign +1, min face for sign -1).
	var center := bounds.position + bounds.size * 0.5
	var handles := PackedVector3Array()
	for handle_id in range(6):
		var axis: int = HANDLE_AXIS[handle_id]
		var sign: float = HANDLE_SIGN[handle_id]
		var p := center
		p[axis] = bounds.position[axis] + bounds.size[axis] if sign > 0.0 else bounds.position[axis]
		handles.append(p)
	gizmo.add_handles(handles, get_material(&"mesh_resize_handles", gizmo), PackedInt32Array())

func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return HANDLE_NAMES[handle_id]

func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	var node := gizmo.get_node_3d()
	_drag_start_position = node.position
	_drag_start_basis = node.global_transform.basis
	_drag_start_scale = node.scale
	_drag_start_bounds = _get_local_bounds(node)
	_drag_is_box = node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh
	# Bundles every property either path can change — simplest thing that's
	# still enough to fully restore on cancel/undo (see _commit_handle).
	var box_size := ((node as MeshInstance3D).mesh as BoxMesh).size if _drag_is_box else Vector3.ZERO
	return {"position": node.position, "scale": node.scale, "size": box_size}

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node := gizmo.get_node_3d()
	var axis: int = HANDLE_AXIS[handle_id]
	var sign: float = HANDLE_SIGN[handle_id]

	# Shared by both paths: where the drag-start anchor/dragged faces sit in
	# WORLD space, measured along the axis from the drag-start origin — all
	# computed fresh from the drag-start snapshot every call, never from the
	# node's current (already-moved) state, so the anchor can't creep.
	var axis_world: Vector3 = _drag_start_basis * _unit_axis(axis)
	var axis_world_unit := axis_world.normalized()
	var start_center_world := _parent_relative_to_world(node, _drag_start_position)

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var closest_world := _closest_point_on_line_to_ray(start_center_world, axis_world, ray_origin, ray_dir)
	var dragged_face_offset := (closest_world - start_center_world).dot(axis_world_unit)

	if _drag_is_box:
		# Lone BoxMesh: the anchor/dragged faces ARE the geometry itself
		# (size is mutable), so their offsets are just ±half the drag-start
		# size — on whichever side `sign` says is the one being dragged, with
		# the OTHER side (-sign) staying anchored.
		var start_half: float = _drag_start_bounds.size[axis] * 0.5
		var anchor_face_offset := -sign * start_half
		# Dragging the +face can only push it further in the +direction past
		# the anchor (clamp from below); dragging the -face only further in
		# the -direction (clamp from above) — same MIN_SIZE floor either way.
		if sign > 0.0:
			dragged_face_offset = maxf(dragged_face_offset, anchor_face_offset + MIN_SIZE)
		else:
			dragged_face_offset = minf(dragged_face_offset, anchor_face_offset - MIN_SIZE)

		var new_axis_size := absf(dragged_face_offset - anchor_face_offset)
		var center_shift := (dragged_face_offset + anchor_face_offset) * 0.5

		var box := (node as MeshInstance3D).mesh as BoxMesh
		var new_size := box.size
		new_size[axis] = new_axis_size
		box.size = new_size
		node.global_position = start_center_world + axis_world_unit * center_shift
	else:
		# Everything else: geometry is fixed (the combined mesh bounds,
		# captured once at drag-start in _drag_start_bounds), so the anchor/
		# dragged faces are that fixed local extent scaled by the drag-start
		# scale — solving for a NEW scale (and the position shift that keeps
		# the anchor face fixed) instead of a new size. Works identically
		# whether `node` is a single non-box MeshInstance3D or the root of a
		# whole multi-part instanced scene, since scale/position are both
		# plain Node3D properties either way.
		var aabb_min: float = _drag_start_bounds.position[axis]
		var aabb_max: float = aabb_min + _drag_start_bounds.size[axis]
		var local_extent := aabb_max - aabb_min
		if absf(local_extent) < 0.0001:
			return   ## degenerate bounds (zero thickness on this axis) — nothing sensible to drag

		# The anchor is whichever local extreme is OPPOSITE the face being
		# dragged: dragging the +face (sign>0) anchors aabb_min, dragging the
		# -face (sign<0) anchors aabb_max.
		var anchor_local: float = aabb_min if sign > 0.0 else aabb_max
		var anchor_face_offset := anchor_local * _drag_start_scale[axis]
		if sign > 0.0:
			dragged_face_offset = maxf(dragged_face_offset, anchor_face_offset + MIN_SIZE)
		else:
			dragged_face_offset = minf(dragged_face_offset, anchor_face_offset - MIN_SIZE)

		# Reduces exactly to the old sign=+1 formulas (anchor_local = aabb_min,
		# local_extent unchanged) when sign is +1.
		var new_scale_axis := (dragged_face_offset - anchor_face_offset) / (local_extent * sign)
		var origin_shift := anchor_face_offset - anchor_local * new_scale_axis

		var new_scale := node.scale
		new_scale[axis] = new_scale_axis
		node.scale = new_scale
		node.global_position = start_center_world + axis_world_unit * origin_shift

	# Force the gizmo's own overlay (wireframe + handle dots) to redraw this
	# frame instead of waiting for the editor's next independent refresh —
	# without this, the underlying mesh/node transform updates live but the
	# orange overlay visibly lags a frame or more behind it during a fast drag.
	node.update_gizmos()

func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node := gizmo.get_node_3d()
	if cancel:
		node.position = restore.position
		if _drag_is_box:
			((node as MeshInstance3D).mesh as BoxMesh).size = restore.size
		else:
			node.scale = restore.scale
		return

	_undo_redo.create_action("Resize Mesh")
	_undo_redo.add_do_property(node, &"position", node.position)
	_undo_redo.add_undo_property(node, &"position", restore.position)
	if _drag_is_box:
		var box := (node as MeshInstance3D).mesh as BoxMesh
		_undo_redo.add_do_property(box, &"size", box.size)
		_undo_redo.add_undo_property(box, &"size", restore.size)
	else:
		_undo_redo.add_do_property(node, &"scale", node.scale)
		_undo_redo.add_undo_property(node, &"scale", restore.scale)
	_undo_redo.commit_action(false)   ## false: the live edit already applied the do-values, don't reapply

## The fixed (pre-scale, local/object-space) bounds a drag's anchor/dragged
## faces are measured against.
## - A lone MeshInstance3D with a BoxMesh: mirrors its own mutable `size`,
##   centered on the origin (same convention as the built-in BoxShape3D
##   gizmo).
## - Everything else: the union of every MeshInstance3D found inside `node`
##   (itself included, if it is one) — each one's own Mesh.get_aabb(),
##   transformed from ITS local space into `node`'s local space, then merged
##   together. Most imported meshes (a tree, a character, a whole glb scene)
##   are NOT centered on their own origin (a tree's origin usually sits at
##   its base, not its middle) — that's fine, the anchor/dragged math in
##   _set_handle works off whatever bounds.position/size this returns, with
##   no assumption that they straddle zero.
func _get_local_bounds(node: Node3D) -> AABB:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
		var half: Vector3 = ((node as MeshInstance3D).mesh as BoxMesh).size * 0.5
		return AABB(-half, ((node as MeshInstance3D).mesh as BoxMesh).size)

	var meshes := _find_mesh_instances(node)
	if meshes.is_empty():
		return AABB()
	var node_inverse := node.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for mi in meshes:
		var local_transform := node_inverse * mi.global_transform
		var transformed := _transform_aabb(local_transform, mi.mesh.get_aabb())
		result = transformed if first else result.merge(transformed)
		first = false
	return result

## Every MeshInstance3D with a mesh assigned, anywhere under `node`
## (including `node` itself).
func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_mesh_instances(child))
	return out

## `aabb` transformed by `t`, computed corner-by-corner (not a component-wise
## scale of position/size) so this stays correct even when `t` includes
## rotation, which a mesh nested inside a rotated child commonly does.
func _transform_aabb(t: Transform3D, aabb: AABB) -> AABB:
	var result := AABB(t * aabb.position, Vector3.ZERO)
	for i in range(1, 8):
		var corner := aabb.position + Vector3(
			aabb.size.x if i & 1 else 0.0,
			aabb.size.y if i & 2 else 0.0,
			aabb.size.z if i & 4 else 0.0)
		result = result.expand(t * corner)
	return result

## `local_position` (e.g. _drag_start_position, a Node3D's local `position`)
## converted to world space via the node's PARENT's current global transform
## — not the node's own, since by the time this is called mid-drag the
## node's own transform has already moved away from where the drag started.
func _parent_relative_to_world(node: Node3D, local_position: Vector3) -> Vector3:
	var parent := node.get_parent_node_3d()
	return parent.global_transform * local_position if parent else local_position

func _unit_axis(axis_index: int) -> Vector3:
	var axis := Vector3.ZERO
	axis[axis_index] = 1.0
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
