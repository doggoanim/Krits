class_name FocusPop
extends Node
## The menu's focus look, replacing Godot's default focus ring. A control that
## gains focus (keyboard OR mouse hover — hovering takes focus, so there's only
## ever one "selected" control) grows a little, pushing its neighbours aside in
## their container, like the pause menu's list does. A textured Button also
## swaps to a random one of the theme's three hand-drawn button textures each
## time it's focused, so the selection never looks exactly the same twice.
##
## Use FocusPop.attach_all(root) once a screen's controls exist — it adds one of
## these as a child of every Button / TextureButton / HSlider underneath `root`.
## Per-control opt-outs/tweaks via node metadata (set in the scene):
##   no_focus_pop = true      leave this control alone (it has its own focus look)
##   focus_pop_scale = true   grow by SCALING (visual only) instead of resizing, so
##                            nothing around it moves — for grids/scroll lists
##                            (attach_all(root, true) sets this on everything)
##   focus_pop_grow = 1.0     don't resize it when focused (default GROW); for
##                            controls whose neighbours' alignment matters
##
## A Button with its own local `hover` stylebox (the save slots) shows THAT when
## focused instead of a random texture; one with no textured theme styles gets
## just the growth.

const SKIP_META := &"no_focus_pop"
const GROW_META := &"focus_pop_grow"
const SCALE_META := &"focus_pop_scale"
const LOOKS_META := &"focus_pop_looks"   ## Array of StyleBox to pick from on focus, instead of the theme's
const ATTACHED_META := &"_focus_pop_attached"
const GROW := 1.12           ## how much bigger a focused control gets
const GROW_TIME := 0.12
const LOOK_STYLES: Array[StringName] = [&"normal", &"hover"]       ## the styles replaced while focused
const TEXTURE_CHOICES: Array[StringName] = [&"normal", &"hover", &"pressed"]   ## the three textures to pick from

var target: Control

var _grow := GROW
var _tween: Tween
var _captured := false
var _base_min := Vector2.ZERO
var _base_font := 0
var _saved_styles := {}   ## style name -> the control's own StyleBox override, or null if it had none

static func attach_all(root: Node, scale_only := false) -> void:
	for node in root.find_children("*", "Control", true, false):
		if node.has_meta(SKIP_META) or node.has_meta(ATTACHED_META):
			continue
		if node is Button or node is TextureButton or node is HSlider:
			if scale_only:
				node.set_meta(SCALE_META, true)
			var pop := FocusPop.new()
			pop.target = node
			node.set_meta(ATTACHED_META, true)
			node.add_child(pop)

func _ready() -> void:
	_grow = target.get_meta(GROW_META, GROW)
	target.focus_entered.connect(_on_focus_entered)
	target.focus_exited.connect(_on_focus_exited)
	target.mouse_entered.connect(_on_mouse_entered)
	if target is BaseButton:
		(target as BaseButton).pressed.connect(UiSfx.click)

func _on_mouse_entered() -> void:
	var base := target as BaseButton
	if (base != null and base.disabled) or target.focus_mode == Control.FOCUS_NONE:
		return
	if _in_inventory():
		return   # the inventory only focuses on click (or keyboard), never on hover
	target.grab_focus()   # hovering selects, same as the keyboard

func _in_inventory() -> bool:
	var node: Node = target.get_parent()
	while node != null:
		if node is InventoryMenu:
			return true
		node = node.get_parent()
	return false

func _on_focus_entered() -> void:
	UiSfx.focus()
	if not _captured:
		_captured = true
		_base_min = target.custom_minimum_size
		if _base_min == Vector2.ZERO:
			_base_min = target.get_combined_minimum_size()
		if target is Button:
			_base_font = target.get_theme_font_size(&"font_size")
	var button := target as Button
	if button != null:
		_apply_look(button)
	_animate(_grow)

func _on_focus_exited() -> void:
	var button := target as Button
	if button != null:
		_restore_look(button)
	_animate(1.0)

func _animate(factor: float) -> void:
	if _grow == 1.0:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	if target.has_meta(SCALE_META):
		# Visual-only: scale around the centre, drawn above its neighbours.
		target.pivot_offset = target.size * 0.5
		target.z_index = 1 if factor > 1.0 else 0
		_tween = target.create_tween().set_trans(Tween.TRANS_BACK if factor > 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(target, "scale", Vector2.ONE * factor, GROW_TIME)
		return
	_tween = target.create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK if factor > 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(target, "custom_minimum_size", _base_min * factor, GROW_TIME)
	if _base_font > 0:
		_tween.tween_method(_set_font_size, float(target.get_theme_font_size(&"font_size")),
				float(_base_font) * factor, GROW_TIME)

func _set_font_size(value: float) -> void:
	target.add_theme_font_size_override(&"font_size", int(round(value)))

func _apply_look(button: Button) -> void:
	var look := _pick_look(button)
	if look == null:
		return
	for style_name in LOOK_STYLES:
		_saved_styles[style_name] = button.get_theme_stylebox(style_name) \
				if button.has_theme_stylebox_override(style_name) else null
		button.add_theme_stylebox_override(style_name, look)

func _restore_look(button: Button) -> void:
	for style_name in _saved_styles:
		var original: StyleBox = _saved_styles[style_name]
		if original == null:
			button.remove_theme_stylebox_override(style_name)
		else:
			button.add_theme_stylebox_override(style_name, original)
	_saved_styles.clear()

func _pick_look(button: Button) -> StyleBox:
	# A control can carry its own set of looks (e.g. nine-sliced plates for a
	# tall slot, which the theme's stretch-to-fit textures would distort).
	if button.has_meta(LOOKS_META):
		var looks: Array = button.get_meta(LOOKS_META)
		if not looks.is_empty():
			return looks.pick_random()
	if button.has_theme_stylebox_override(&"hover"):
		return button.get_theme_stylebox(&"hover")   # the control's own selected look (e.g. a slot's grey)
	var textured: Array[StyleBox] = []
	for style_name in TEXTURE_CHOICES:
		var style := button.get_theme_stylebox(style_name)
		if style is StyleBoxTexture:
			textured.append(style)
	return textured.pick_random() if not textured.is_empty() else null
