class_name DeathOverlay
extends Node
## Draws the player ABOVE everything, the iris's black included, for the Mario
## death fall: the player drops out of the open gap and keeps falling over the
## black instead of vanishing behind it.
##
## Same trick OutlineSystem uses: a second camera on the same World3D, synced to
## the gameplay camera, that only sees meshes on OVERLAY_LAYER_MASK. It renders
## into a transparent SubViewport shown by a TextureRect on a CanvasLayer that
## sits above LoadingScreen. show_player() tags the player's meshes with that
## layer (they're still drawn normally underneath, where the black hides them);
## clear() removes the tag and the overlay.

const OVERLAY_LAYER_BIT := 11   ## 0-indexed render layer; unused by OutlineSystem (1) and CharacterFillLight (2)
const OVERLAY_LAYER_MASK := 1 << OVERLAY_LAYER_BIT
const CANVAS_LAYER := LoadingScreen.COVER_LAYER + 1

var _viewport: SubViewport
var _cam: Camera3D
var _canvas: CanvasLayer
var _source: Camera3D
var _tagged: Array[MeshInstance3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)   # shares the main World3D (own_world_3d stays false)
	_cam = Camera3D.new()
	_cam.cull_mask = OVERLAY_LAYER_MASK
	_cam.current = true
	_viewport.add_child(_cam)
	_canvas = CanvasLayer.new()
	_canvas.layer = CANVAS_LAYER
	_canvas.visible = false
	add_child(_canvas)
	var rect := TextureRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture = _viewport.get_texture()
	_canvas.add_child(rect)
	get_viewport().size_changed.connect(_resize)
	_resize()
	set_process(false)

## Puts `subject`'s meshes on the overlay, seen through a copy of `source_cam`.
func show_player(subject: Node, source_cam: Camera3D) -> void:
	clear()
	_source = source_cam
	_tag(subject)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas.visible = true
	set_process(true)
	_sync_camera()

func clear() -> void:
	for mi in _tagged:
		if is_instance_valid(mi):
			mi.layers &= ~OVERLAY_LAYER_MASK
	_tagged.clear()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_canvas.visible = false
	set_process(false)

func _process(_delta: float) -> void:
	_sync_camera()

func _tag(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.layers |= OVERLAY_LAYER_MASK
		_tagged.append(mi)
	for child in node.get_children():
		_tag(child)

func _sync_camera() -> void:
	if not is_instance_valid(_source):
		return
	_cam.global_transform = _source.global_transform
	_cam.fov = _source.fov
	_cam.near = _source.near
	_cam.far = _source.far
	_cam.projection = _source.projection
	_cam.h_offset = _source.h_offset
	_cam.v_offset = _source.v_offset

func _resize() -> void:
	_viewport.size = get_viewport().get_visible_rect().size
