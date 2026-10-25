@tool
extends EditorScenePostImport
## Attach this as a glb/gltf's import Script (Import tab -> Script field,
## scene-level, not per-node) to flag specific baked-in colliders as ones the
## camera's spring arm should be pushed out by (see player_camera.gd's
## GROUND_LAYER / project.godot's "camera_push" layer 8) instead of letting
## the camera clip through them like ordinary world geometry does.
##
## Controlled entirely by naming in Blender, not guessed here: a collision
## object meant to push the camera is named "..._camerapush-col" (or
## -colonly/-convcol/-convcolonly) so Godot's glTF importer turns it into a
## StaticBody3D named "..._camerapush" (the -col* suffix itself is stripped
## on import, since that's what tells Godot to generate the body in the
## first place). Anything else — a collider with no "_camerapush" in its
## name — is left exactly as Godot generated it. One script, reused for
## every asset in the project; nothing to edit here per-model.

const CAMERA_PUSH_MARKER := "_camerapush"
const CAMERA_PUSH_LAYER := 1 << 7   ## matches CameraRig.GROUND_LAYER in player/player_camera.gd

func _post_import(scene: Node) -> Object:
	_apply(scene)
	return scene

func _apply(node: Node) -> void:
	if node is StaticBody3D and CAMERA_PUSH_MARKER in node.name:
		node.collision_layer |= CAMERA_PUSH_LAYER
	for child in node.get_children():
		_apply(child)
