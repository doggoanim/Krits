extends Node
## Global game state: stats, story flags, unlocked spawnpoints, saving.

const SAVE_PATH := "user://save.json"

var stats := PlayerStats.new()
var story_flags := {}
var unlocked_spawns: Array[StringName] = []
var last_spawn: StringName = &""
var god_mode := false
var input_locked := false   ## true during encounter transitions

func _process(delta: float) -> void:
	stats.tick(delta)

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

## Wipes the save file from disk and resets all in-memory progress to a
## fresh-save state. Debug-only (see DebugTools).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	stats = PlayerStats.new()
	story_flags.clear()
	unlocked_spawns.clear()
	last_spawn = &""

## Whether there's a save file to resume — MainMenu uses this to decide
## whether "Continue" should be enabled.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save() -> void:
	var data := {
		"stats": stats.to_dict(), "flags": story_flags,
		"spawns": unlocked_spawns.map(func(s): return String(s)),
		"last_spawn": String(last_spawn),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	stats.from_dict(parsed.get("stats", {}))
	story_flags = parsed.get("flags", {})
	unlocked_spawns.clear()
	for s in parsed.get("spawns", []): unlocked_spawns.append(StringName(s))
	last_spawn = StringName(parsed.get("last_spawn", ""))
	return true
