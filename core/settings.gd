extends Node
## Player-facing options (autoload `Settings`). One flat store of
## "section/name" keys with defaults, persisted to user://settings.cfg and
## applied at startup — so choices hold whether or not the menu is opened.
##
## To add an option:
##   1. add its key + default to DEFAULTS,
##   2. add a case for it in _apply() if it needs to change something global
##      (anything that merely reads it, like the camera, can instead call
##      get_value() and/or listen to `changed`),
##   3. add a control to settings_screen.tscn with `metadata/setting` set to
##      the key — the screen binds it automatically, no script change.
##
## Sections (the part before the "/") are the Settings screen's categories:
## display, audio, controls, accessibility.

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const SAVE_DELAY := 0.5   ## seconds of quiet before writing, so dragging a slider isn't a disk write per frame

# Window modes (the ids used by the Window Mode dropdown in settings_screen.tscn).
const WINDOWED := 0
const FULLSCREEN := 1             ## borderless, fills the screen
const EXCLUSIVE_FULLSCREEN := 2   ## matches the project's default window mode

const BINDINGS_KEY := &"controls/bindings"   ## {action: physical keycode} — only keys changed from default

const DEFAULTS := {
	&"display/window_mode": EXCLUSIVE_FULLSCREEN,
	&"display/vsync": true,
	&"display/resolution": 900,         ## windowed-mode size, as the window HEIGHT (16:9 — see _windowed_size())
	&"display/fps_cap": 0,              ## 0 = unlimited
	&"display/render_distance": 4000,   ## camera far plane, in metres
	&"display/pixelation": 3,           ## PixelateEffect block size in screen pixels (1 = off)
	&"audio/master": 1.0,
	&"audio/music": 1.0,
	&"audio/sfx": 1.0,
	&"audio/mute_unfocused": false,
	&"controls/camera_sens": 1.0,       ## multiplier on the camera's base sensitivity
	&"controls/invert_y": false,
	&"controls/bindings": {},
	&"accessibility/screen_shake": true,
	&"accessibility/hitstop": 1.0,            ## multiplier on hit-stop freeze time (0 = off)
	&"accessibility/text_speed": 1.0,         ## multiplier on dialogue typewriter speed
}

const _VOLUME_BUSES := {
	&"audio/master": &"Master",
	&"audio/music": &"Music",
	&"audio/sfx": &"SFX",
}

var _values := {}
var _focused := true
var _save_timer: Timer

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	for key in DEFAULTS:
		_values[key] = _copy(DEFAULTS[key])
	_load()
	for key in DEFAULTS:
		_apply(key)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_apply(&"audio/master")
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_apply(&"audio/master")
		NOTIFICATION_WM_CLOSE_REQUEST:
			save()

# --- Public API -----------------------------------------------------------

func get_value(key: StringName) -> Variant:
	return _values.get(key, DEFAULTS.get(key))

func set_value(key: StringName, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Settings: unknown key %s" % key)
		return
	_values[key] = value
	_apply(key)
	changed.emit(key)
	_save_timer.start(SAVE_DELAY)

## Resets every key in `section` ("display", "audio", ...), or all of them
## when `section` is empty, back to its default.
func reset_defaults(section := "") -> void:
	for key in DEFAULTS:
		if section == "" or String(key).begins_with(section + "/"):
			_values[key] = _copy(DEFAULTS[key])
			_apply(key)
			changed.emit(key)
	_save_timer.start(SAVE_DELAY)

## Writes now (also called on a timer after any change, and on quit).
func save() -> void:
	var cfg := ConfigFile.new()
	for key in DEFAULTS:
		var parts := String(key).split("/")
		cfg.set_value(parts[0], parts[1], _values[key])
	cfg.save(PATH)

# --- Key bindings ---------------------------------------------------------

func get_binding(action: StringName) -> Key:
	var overrides: Dictionary = _values[BINDINGS_KEY]
	return overrides.get(String(action), InputSetup.default_key(action))

## Rebinds `action` to `keycode`. If another action already uses that key the
## two swap, so no action is ever left unbound.
func set_binding(action: StringName, keycode: Key) -> void:
	var old := get_binding(action)
	var overrides: Dictionary = _values[BINDINGS_KEY].duplicate()
	for other in InputSetup.BINDINGS:
		if other != action and get_binding(other) == keycode:
			overrides[String(other)] = old
	overrides[String(action)] = keycode
	set_value(BINDINGS_KEY, overrides)

# --- Applying -------------------------------------------------------------

func _apply(key: StringName) -> void:
	match key:
		&"audio/master", &"audio/music", &"audio/sfx", &"audio/mute_unfocused":
			_apply_volumes()
		&"display/window_mode":
			_apply_window_mode()
		&"display/resolution":
			if int(_values[&"display/window_mode"]) == WINDOWED:
				_apply_window_mode()
		&"display/vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if _values[key] else DisplayServer.VSYNC_DISABLED)
		&"display/fps_cap":
			Engine.max_fps = int(_values[key])
		&"controls/bindings":
			for action in InputSetup.BINDINGS:
				InputSetup.bind_key(action, get_binding(action))
		# display/pixelation is read by PixelateEffect, display/render_distance, controls/camera_sens, controls/invert_y and
		# accessibility/screen_shake are read by the camera / HUD themselves.

func _apply_volumes() -> void:
	for key in _VOLUME_BUSES:
		var idx := AudioServer.get_bus_index(_VOLUME_BUSES[key])
		if idx < 0:
			continue
		var v: float = _values[key]
		var muted := v <= 0.0
		if _VOLUME_BUSES[key] == &"Master" and _values[&"audio/mute_unfocused"] and not _focused:
			muted = true
		AudioServer.set_bus_mute(idx, muted)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))

func _apply_window_mode() -> void:
	match int(_values[&"display/window_mode"]):
		WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Coming back from (exclusive) fullscreen can leave the window
			# without its title bar — borderless is a separate flag from the mode.
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_place_window.call_deferred()   # the mode change needs a frame to settle before sizing
		FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

## Sizes and centres the window for Windowed mode (from the Resolution setting),
## shrunk to fit if the screen can't hold it.
func _place_window() -> void:
	if int(_values[&"display/window_mode"]) != WINDOWED:
		return
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var wanted := _windowed_size()
	var size := Vector2i(mini(wanted.x, usable.size.x), mini(wanted.y, usable.size.y))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)

## The Resolution dropdown stores the window height; width follows at 16:9.
func _windowed_size() -> Vector2i:
	var h := int(_values[&"display/resolution"])
	return Vector2i(roundi(h * 16.0 / 9.0), h)

# --- Persistence ----------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in DEFAULTS:
		var parts := String(key).split("/")
		var fallback: Variant = DEFAULTS[key]
		var value: Variant = cfg.get_value(parts[0], parts[1], fallback)
		if typeof(value) == typeof(fallback):
			_values[key] = value
		elif typeof(fallback) == TYPE_FLOAT and typeof(value) == TYPE_INT:
			_values[key] = float(value)

static func _copy(v: Variant) -> Variant:
	return v.duplicate() if v is Dictionary else v
