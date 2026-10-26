@tool
extends EditorPlugin
## Registers mesh_resize_gizmo_plugin.gd so a MeshInstance3D using a BoxMesh
## or PlaneMesh gets drag-to-resize handles in the 3D viewport — see that
## file for the actual gizmo logic. This file is just the plugin lifecycle
## glue Godot requires (register on enable, unregister on disable).

var _gizmo_plugin: EditorNode3DGizmoPlugin

func _enter_tree() -> void:
	_gizmo_plugin = preload("res://addons/mesh_resize_gizmo/mesh_resize_gizmo_plugin.gd").new(get_undo_redo())
	add_node_3d_gizmo_plugin(_gizmo_plugin)

func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmo_plugin)
	_gizmo_plugin = null
