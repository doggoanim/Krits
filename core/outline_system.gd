class_name OutlineSystem
extends Node
## Draws one black outline around the OUTER silhouette of every character
## marked for it — instead of CelOutline's old per-mesh inverted-hull trick,
## which gave each of a rigged character's ~11 separate skinned
## MeshInstance3Ds (torso, each limb, hair, head, ...) its own independently
## grown hull. Those hulls had no idea the others existed, so two parts that
## only just touch (shoulder/torso, waist/legs) could each poke a hull
## slightly past the other's real surface right at the seam — a stray
## interior outline line, not the clean single silhouette a toon character
## is supposed to read as.
##
## How this one avoids that entirely: a mesh opts in with mark() below,
## which just adds OUTLINE_LAYER_MASK to its render layers alongside
## whatever it already had — still rendered normally by the main camera,
## nothing changes there. A *second* camera (`_cam`, below), sharing the
## same World3D but seeing *only* that layer, is kept in perfect sync with
## the real gameplay camera every frame (transform/fov/near/far) and renders
## into a private, transparent-background SubViewport. That capture has
## nothing in it but the marked meshes, silhouetted against full
## transparency — alpha only ever answers "is anything here", never "which
## of 11 meshes", so there is no seam for an artifact to come from.
## outline_overlay.gdshader then dilates that silhouette's alpha by
## `outline_width_px` and keeps only the ring where the dilated value is
## higher than the pixel's own — the outer edge, and only the outer edge —
## composited back over the real scene as a transparent CanvasLayer overlay.
## Being screen-space, the ring is a constant pixel width regardless of the
## character's distance from the camera, rather than the old technique's
## world-space grow amount reading thicker up close and thinner far away.
##
## Usage: Main creates exactly one of these for the whole game and calls
## follow() once with whatever the active gameplay camera is (see main.gd).
## Every character that wants outlining calls the static mark() on each of
## its MeshInstance3Ds once, right after setting up its material — ModelUtil
## does this for any rigged model via the outline_hook param of
## apply_cel_shading(). A model that should NOT be outlined (a cutscene
## prop, say) just never calls mark() — nothing else to opt out of.

const OUTLINE_LAYER_BIT := 1   ## 0-indexed render layer bit -> VisualInstance3D.layers value 2
const OUTLINE_LAYER_MASK := 1 << OUTLINE_LAYER_BIT

@export var outline_width_px := 3.0
@export var outline_color := Color.BLACK

var _viewport: SubViewport
var _cam: Camera3D
var _overlay_material: ShaderMaterial
var _source_cam: Camera3D   ## whatever camera follow() last pointed this at

## Adds this mesh to the outline pass without touching its normal
## visibility/layer 1 membership — `layers` is a bitmask, so a mesh can be
## seen by both the main camera and this system's camera at once.
static func mark(mi: VisualInstance3D) -> void:
	mi.layers |= OUTLINE_LAYER_MASK

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# own_world_3d deliberately left false (the default): this has to see the
	# exact same World3D as the main camera — the same characters, mid
	# whatever pose they're actually in — not a separate copy of the scene.
	add_child(_viewport)

	_cam = Camera3D.new()
	_cam.cull_mask = OUTLINE_LAYER_MASK
	_cam.current = true
	_viewport.add_child(_cam)

	var canvas := CanvasLayer.new()
	canvas.layer = -10   # CanvasLayers always draw above the 3D scene regardless of this value; this just keeps it below the HUD/menus (their CanvasLayers default to layer 1)
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = preload("res://shading/outline_overlay.gdshader")
	_overlay_material.set_shader_parameter(&"silhouette", _viewport.get_texture())
	overlay.material = _overlay_material
	canvas.add_child(overlay)

	get_viewport().size_changed.connect(_resize)
	_resize()
	_apply_style()

func _resize() -> void:
	_viewport.size = get_viewport().get_visible_rect().size

func _apply_style() -> void:
	_overlay_material.set_shader_parameter(&"outline_color", outline_color)
	_overlay_material.set_shader_parameter(&"width_px", outline_width_px)

## Points this system's private camera at whatever the game's real active
## camera is — call once the gameplay camera exists (see main.gd), and again
## if the active camera ever changes (e.g. a cutscene camera taking over).
func follow(camera: Camera3D) -> void:
	_source_cam = camera

func _process(_delta: float) -> void:
	if _source_cam == null:
		return
	_cam.global_transform = _source_cam.global_transform
	_cam.fov = _source_cam.fov
	_cam.near = _source_cam.near
	_cam.far = _source_cam.far
	_cam.projection = _source_cam.projection
	_cam.h_offset = _source_cam.h_offset
	_cam.v_offset = _source_cam.v_offset
