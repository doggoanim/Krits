class_name Drops
extends RefCounted
## Reads data/drops.cfg — the one file to edit to change what enemies drop.
## EnemyLibrary calls for_enemy() when it builds each enemy. A line is
## `item_id = [chance, min, max]`; see the file's header for details.

const PATH := "res://data/drops.cfg"

static var _cfg: ConfigFile

static func for_enemy(enemy_id: StringName) -> Array[ItemDrop]:
	if _cfg == null:
		_cfg = ConfigFile.new()
		var err := _cfg.load(PATH)   # missing file -> no drops anywhere
		if err != OK:
			push_error("Drops: could not load %s (error %d) — is data/*.cfg in the export filter?" % [PATH, err])
	var out: Array[ItemDrop] = []
	var section := String(enemy_id)
	if not _cfg.has_section(section):
		return out
	for key in _cfg.get_section_keys(section):
		var entry: Variant = _cfg.get_value(section, key)
		if not (entry is Array) or (entry as Array).size() < 1:
			push_warning("drops.cfg: [%s] %s should look like [chance, min, max]" % [section, key])
			continue
		var values: Array = entry
		var drop := ItemDrop.new()
		drop.item_id = StringName(key)
		drop.chance = clampf(float(values[0]), 0.0, 1.0)
		drop.min_count = int(values[1]) if values.size() > 1 else 1
		drop.max_count = int(values[2]) if values.size() > 2 else drop.min_count
		out.append(drop)
	return out
