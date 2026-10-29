class_name Descriptions
extends RefCounted
## Reads data/descriptions.cfg — the one file to edit when you want to reword
## an item, ability or piece of gear. Libraries call text() with their
## built-in text as the fallback, so a missing entry never breaks anything.

const PATH := "res://data/descriptions.cfg"

static var _cfg: ConfigFile

static func text(section: String, id: StringName, fallback := "") -> String:
	if _cfg == null:
		_cfg = ConfigFile.new()
		var err := _cfg.load(PATH)   # missing file -> everything falls back
		if err != OK:
			# Exports only ship non-resource files that match the preset's
			# include filter (Export > Resources > "Filters to export
			# non-resource files" must contain data/*.cfg).
			push_error("Descriptions: could not load %s (error %d) — is data/*.cfg in the export filter?" % [PATH, err])
	var value: String = _cfg.get_value(section, String(id), "")
	if value != "":
		return value
	if fallback == "" and section == "names":
		return String(id).capitalize()   # never show a blank name ("super_jump" -> "Super Jump")
	return fallback
