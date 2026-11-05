class_name RenderDebug
extends Node
## Developer-only switches for hunting rendering glitches: Ctrl+Shift+1..9, 0
## flip one effect each so you can see which one causes an artifact. Resets on
## level change (Main re-applies the level's lighting), and does nothing in a
## release build. A small readout shows what is currently off.

const KEYS: Dictionary = {
	KEY_1: &"ssao",
	KEY_2: &"glow",
	KEY_3: &"volumetric fog",
	KEY_4: &"sun shadows",
	KEY_5: &"spot/omni shadows",
	KEY_6: &"watercolor overlay",
	KEY_7: &"outlines",
	KEY_8: &"distance haze",
	KEY_9: &"color grading",
	KEY_0: &"world toon shading",
}

var env: Environment
var sun: DirectionalLight3D
var _main: Node
var _off: Dictionary = {}   # effect name -> true while switched off
var _label: Label

func setup(main: Node, e: Environment, s: DirectionalLight3D) -> void:
	_main = main
	env = e
	sun = s

func _ready() -> void:
	if not OS.is_debug_build():
		set_process_input(false)
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 230)
	_label.add_theme_font_size_override(&"font_size", 16)
	_label.add_theme_color_override(&"font_color", Color.YELLOW)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_label)
	_refresh_label()

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not (k.ctrl_pressed and k.shift_pressed):
		return
	if not KEYS.has(k.keycode):
		return
	get_viewport().set_input_as_handled()
	var effect: StringName = KEYS[k.keycode]
	var turn_off := not _off.has(effect)
	if turn_off:
		_off[effect] = true
	else:
		_off.erase(effect)
	_apply(effect, not turn_off)
	_refresh_label()

func _apply(effect: StringName, on: bool) -> void:
	match effect:
		&"ssao": env.ssao_enabled = on
		&"glow": env.glow_enabled = on
		&"volumetric fog": env.volumetric_fog_enabled = on
		&"sun shadows": sun.shadow_enabled = on
		&"distance haze": env.fog_enabled = on
		&"color grading": env.adjustment_enabled = on
		&"spot/omni shadows":
			for l in get_tree().root.find_children("*", "Light3D", true, false):
				if l is OmniLight3D or l is SpotLight3D:
					# remember the authored value so switching back restores it
					if not l.has_meta(&"_shadow_was"):
						l.set_meta(&"_shadow_was", (l as Light3D).shadow_enabled)
					(l as Light3D).shadow_enabled = on and bool(l.get_meta(&"_shadow_was"))
		&"watercolor overlay": _set_layers(&"WatercolorEffect", on)
		&"outlines": _set_layers(&"OutlineSystem", on)
		&"world toon shading": _toggle_toon(on)

func _set_layers(script_class: StringName, on: bool) -> void:
	for n in _main.get_children():
		if n.get_script() != null and (n.get_script() as Script).get_global_name() == script_class:
			for c in n.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = on

## Off = swap the level's props back to their original materials; on = redo them.
func _toggle_toon(on: bool) -> void:
	var level: Node = _main.get("level")
	if level == null:
		return
	if on:
		WorldToon.apply(level)
	else:
		for mi in level.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			for i in m.mesh.get_surface_count():
				var o := m.get_surface_override_material(i)
				if o is ShaderMaterial and (o as ShaderMaterial).shader != null \
						and (o as ShaderMaterial).shader.resource_path.begins_with("res://shading/toon"):
					m.set_surface_override_material(i, null)

func _refresh_label() -> void:
	if _label == null:
		return
	var lines := PackedStringArray(["Ctrl+Shift+ 1 ssao  2 glow  3 vol.fog  4 sun shadow  5 spot shadow",
			"6 watercolor  7 outlines  8 haze  9 grading  0 toon world"])
	if not _off.is_empty():
		lines.append("OFF: " + ", ".join(PackedStringArray(_off.keys().map(func(x: Variant) -> String: return String(x)))))
	_label.text = "\n".join(lines)
