class_name RenderDebug
extends Node
## Developer-only switches for hunting rendering glitches: Ctrl+Shift+1..9, 0
## flip one effect each so you can see which one causes an artifact. Resets on
## level change (Main re-applies the level's lighting), and does nothing in a
## release build. A small readout shows what is currently off.

## Second set, for keyboards/OSes where Ctrl+Shift+digit is taken (Windows uses it
## for input-language switching): plain Ctrl+F1..F10 does the same, in the same order.
const FKEYS: Dictionary = {
	KEY_F1: KEY_1, KEY_F2: KEY_2, KEY_F3: KEY_3, KEY_F4: KEY_4, KEY_F5: KEY_5,
	KEY_F6: KEY_6, KEY_F7: KEY_7, KEY_F8: KEY_8, KEY_F9: KEY_9, KEY_F10: KEY_0,
	KEY_F11: KEY_MINUS, KEY_F12: KEY_EQUAL,
}

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
	KEY_MINUS: &"sun light",
	KEY_EQUAL: &"particles",
}

var env: Environment
var sun: DirectionalLight3D
var _main: Node
var _sun_energy := 1.0   ## remembered when "sun light" is switched off
var _off: Dictionary = {}   # effect name -> true while switched off
var _label: Label
var _view := 0   ## index into VIEWS, Ctrl+` cycles it
const VIEWS: Array = [
	["normal", Viewport.DEBUG_DRAW_DISABLED],
	["UNSHADED (no lighting at all)", Viewport.DEBUG_DRAW_UNSHADED],
	["LIGHTING only", Viewport.DEBUG_DRAW_LIGHTING],
	["OVERDRAW", Viewport.DEBUG_DRAW_OVERDRAW],
	["NORMAL buffer", Viewport.DEBUG_DRAW_NORMAL_BUFFER],
	["SSAO buffer", Viewport.DEBUG_DRAW_SSAO],
	["SUN shadow map", Viewport.DEBUG_DRAW_DIRECTIONAL_SHADOW_ATLAS],
	["SPOT/OMNI shadow atlas", Viewport.DEBUG_DRAW_SHADOW_ATLAS],
]

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
	_label.visible = false   # Ctrl+/ shows the key list; the switches work either way
	_refresh_label()

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not k.ctrl_pressed:
		return
	var code: int = k.keycode
	if code == KEY_SLASH and not k.shift_pressed:   # Ctrl+/ — show/hide the key list
		get_viewport().set_input_as_handled()
		if _label != null:
			_label.visible = not _label.visible
		return
	if code == KEY_QUOTELEFT:   # Ctrl+` — cycle the viewport debug view
		get_viewport().set_input_as_handled()
		_view = (_view + 1) % VIEWS.size()
		get_viewport().debug_draw = VIEWS[_view][1] as Viewport.DebugDraw
		print("RenderDebug view: ", VIEWS[_view][0])
		_refresh_label()
		return
	if FKEYS.has(code) and not k.shift_pressed:
		code = FKEYS[code]
	elif not k.shift_pressed:
		return
	if not KEYS.has(code):
		return
	get_viewport().set_input_as_handled()
	var effect: StringName = KEYS[code]
	var turn_off := not _off.has(effect)
	if effect == &"sun light" and turn_off:
		_sun_energy = sun.light_energy
	if turn_off:
		_off[effect] = true
	else:
		_off.erase(effect)
	_apply(effect, not turn_off)
	print("RenderDebug: %s %s" % [effect, "OFF" if turn_off else "on"])
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
		&"sun light": sun.light_energy = _sun_energy if on else 0.0
		&"particles":
			for p in get_tree().root.find_children("*", "GPUParticles3D", true, false):
				(p as GPUParticles3D).visible = on

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
	var lines := PackedStringArray(["Ctrl+/ hides this.  Ctrl+F1..F12 (or Ctrl+Shift+1..0, -, =):",
			"1 ssao  2 glow  3 vol.fog  4 sun shadow  5 spot shadow",
			"6 watercolor  7 outlines  8 haze  9 grading  10 toon world",
			"11 sun light  12 particles"])
	lines.append("Ctrl+` cycles view: " + String(VIEWS[_view][0]))
	if not _off.is_empty():
		lines.append("OFF: " + ", ".join(PackedStringArray(_off.keys().map(func(x: Variant) -> String: return String(x)))))
	_label.text = "\n".join(lines)
