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
		_cfg.load(PATH)   # missing file -> everything falls back
	var value: String = _cfg.get_value(section, String(id), "")
	return value if value != "" else fallback
