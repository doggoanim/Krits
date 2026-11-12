extends Node
## Autoload: gives every piece of UI text a slight hand-drawn wobble.
## One shared ShaderMaterial (shading/text_wobble.gdshader) is put on every
## Label / RichTextLabel / Button / LineEdit — the ones that already exist and
## any that appear later — unless the node has its own material or is in the
## `no_wobble` group. Toggled by the Accessibility setting "wobbly_text".
##
## Tuning: AMPLITUDE (pixels) and BOIL_FPS (0 = still) below.

const SETTING := &"accessibility/wobbly_text"
const NO_WOBBLE_GROUP := &"no_wobble"
const AMPLITUDE := 1.4
const BOIL_FPS := 0.0

var _material := ShaderMaterial.new()
var _applied: Array[WeakRef] = []   ## nodes we put the material on, so it can be removed again

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material.shader = preload("res://shading/text_wobble.gdshader")
	_material.set_shader_parameter(&"amplitude", AMPLITUDE)
	_material.set_shader_parameter(&"boil_fps", BOIL_FPS)
	get_tree().node_added.connect(_on_node_added)
	Settings.changed.connect(_on_setting_changed)
	if _enabled():
		_apply_to_tree(get_tree().root)

func _enabled() -> bool:
	return bool(Settings.get_value(SETTING))

func _is_text(node: Node) -> bool:
	return node is Label or node is RichTextLabel or node is Button or node is LineEdit

func _on_node_added(node: Node) -> void:
	if _enabled() and _is_text(node):
		_wobble(node)

func _wobble(node: Node) -> void:
	var item := node as CanvasItem
	if item.material != null or node.is_in_group(NO_WOBBLE_GROUP):
		return
	item.material = _material
	_applied.append(weakref(node))

func _apply_to_tree(node: Node) -> void:
	if _is_text(node):
		_wobble(node)
	for child in node.get_children():
		_apply_to_tree(child)

func _on_setting_changed(key: StringName) -> void:
	if key != SETTING:
		return
	if _enabled():
		_apply_to_tree(get_tree().root)
		return
	for ref in _applied:
		var item := ref.get_ref() as CanvasItem
		if item != null and item.material == _material:
			item.material = null
	_applied.clear()
