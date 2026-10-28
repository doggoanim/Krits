extends Node
## Player-facing options (autoload `Settings`): per-bus volume and fullscreen.
## Persisted to user://settings.cfg and applied at startup, so the choice holds
## whether the player opens the menu or not. The UI (SettingsScreen) only reads
## and writes through this API — to add an option, add a key + getter/setter
## here, call its apply function from _apply_all(), and give the screen a row.
##
## Volumes are linear 0..1 per audio bus (buses live in default_bus_layout.tres:
## Master, Music, SFX).

signal changed

const PATH := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]

var _volumes := {&"Master": 1.0, &"Music": 1.0, &"SFX": 1.0}
var _fullscreen := true   # matches the project's default window mode

func _ready() -> void:
	_load()
	_apply_all()

# --- Volume ---------------------------------------------------------------

func get_volume(bus: StringName) -> float:
	return _volumes.get(bus, 1.0)

func set_volume(bus: StringName, value: float) -> void:
	_volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	changed.emit()

func _apply_volume(bus: StringName) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v: float = _volumes[bus]
	AudioServer.set_bus_mute(idx, v <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))

# --- Display --------------------------------------------------------------

func is_fullscreen() -> bool:
	return _fullscreen

func set_fullscreen(on: bool) -> void:
	_fullscreen = on
	_apply_fullscreen()
	changed.emit()

func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if _fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)

# --- Persistence ----------------------------------------------------------

func _apply_all() -> void:
	for bus in BUSES:
		_apply_volume(bus)
	_apply_fullscreen()

func save() -> void:
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("audio", String(bus).to_lower(), _volumes[bus])
	cfg.set_value("display", "fullscreen", _fullscreen)
	cfg.save(PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for bus in BUSES:
		_volumes[bus] = clampf(float(cfg.get_value("audio", String(bus).to_lower(), 1.0)), 0.0, 1.0)
	_fullscreen = bool(cfg.get_value("display", "fullscreen", _fullscreen))
