extends Node
## Global game state: stats, story flags, unlocked spawnpoints, saving.

## Three independent save files, one per slot on the main menu's slot screen
## (see ui/menu/save_slots_screen.gd). `current_slot` is whichever one the
## running game reads from and writes to — set by the menu before it hands
## off to main.tscn, so Main's own Game.load_game() needs no slot argument.
const SLOT_COUNT := 3
## Single-file save from before slots existed; adopted as slot 1 the first
## time it's seen (see _migrate_legacy_save()) so nobody loses progress.
const LEGACY_SAVE_PATH := "user://save.json"

var current_slot := 1
var player_name := "Krits"
var stats := PlayerStats.new()
var inventory := Inventory.new()
var hotbar := Hotbar.new()
var story_flags := {}
var unlocked_spawns: Array[StringName] = []
var last_spawn: StringName = &""
var god_mode := false
var input_locked := false   ## true during encounter transitions

func _ready() -> void:
	_migrate_legacy_save()

func _process(delta: float) -> void:
	stats.tick(delta)
	hotbar.tick(delta)

func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	if not FileAccess.file_exists(slot_path(1)):
		DirAccess.copy_absolute(LEGACY_SAVE_PATH, slot_path(1))
	DirAccess.remove_absolute(LEGACY_SAVE_PATH)

func set_flag(flag: StringName, value: Variant = true) -> void:
	story_flags[flag] = value
	Events.story_flag_changed.emit(flag, value)

func flag(flag_name: StringName, default: Variant = false) -> Variant:
	return story_flags.get(flag_name, default)

func unlock_spawn(id: StringName) -> void:
	last_spawn = id
	if id not in unlocked_spawns:
		unlocked_spawns.append(id)
	Events.spawnpoint_activated.emit(id)
	save()

## Clears every "cleared_<id>" world-enemy flag (leaves other story flags
## alone), so already-defeated overworld enemies count as undefeated again.
## Debug-only (see DebugTools). Doesn't bring back an enemy already
## queue_free()'d this session by itself — the caller reloads the scene too.
func reset_cleared_enemies() -> void:
	for key in story_flags.keys().duplicate():
		if String(key).begins_with("cleared_"):
			story_flags.erase(key)

## Wipes a slot's save file from disk (the current slot if `slot` is left
## at -1) and resets all in-memory progress to a fresh-save state.
func delete_save(slot := -1) -> void:
	var path := slot_path(current_slot if slot < 0 else slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	stats = PlayerStats.new()
	inventory = Inventory.new()
	hotbar = Hotbar.new()
	story_flags.clear()
	unlocked_spawns.clear()
	last_spawn = &""
	player_name = "Krits"

## Whether a slot (the current one if `slot` is left at -1) has a save to
## resume — the slot screen uses this to tell "Empty" from an occupied slot.
func has_save(slot := -1) -> bool:
	return FileAccess.file_exists(slot_path(current_slot if slot < 0 else slot))

## Just enough of a slot's save for the slot screen to label it, without
## loading it into the live game state. Empty dictionary = nothing there.
func slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var stat_dict: Dictionary = parsed.get("stats", {})
	return {
		"name": String(parsed.get("player_name", "Krits")),
		"gold": int(stat_dict.get("gold", 0)),
	}

## Points the running game at `slot` — Main's own load_game() reads from it.
func select_slot(slot: int) -> void:
	current_slot = slot

## Claims `slot` for a brand-new save under `new_name` and writes it to disk
## straight away, so the slot reads as occupied from then on even if the
## game is closed before the first spawnpoint save.
func start_new_game(slot: int, new_name: String) -> void:
	select_slot(slot)
	delete_save(slot)
	player_name = new_name
	save()

func save() -> void:
	var data := {
		"player_name": player_name,
		"stats": stats.to_dict(), "inventory": inventory.to_dict(), "hotbar": hotbar.to_dict(), "flags": story_flags,
		"spawns": unlocked_spawns.map(func(s): return String(s)),
		"last_spawn": String(last_spawn),
	}
	var f := FileAccess.open(slot_path(current_slot), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not has_save():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(current_slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	player_name = String(parsed.get("player_name", "Krits"))
	stats.from_dict(parsed.get("stats", {}))
	inventory.from_dict(parsed.get("inventory", {}))
	hotbar.from_dict(parsed.get("hotbar", {}))
	story_flags = parsed.get("flags", {})
	unlocked_spawns.clear()
	for s in parsed.get("spawns", []): unlocked_spawns.append(StringName(s))
	last_spawn = StringName(parsed.get("last_spawn", ""))
	return true
