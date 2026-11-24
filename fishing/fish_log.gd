class_name FishLog
extends RefCounted
## What the player has caught: per species, how many and the biggest / smallest size (the size
## multiplier FishCatalog.roll_size() hands out). Lives on Game.fish_log, is saved with the game
## and shown in the Fish Journal (ui/fish_journal.gd).

var _records: Dictionary = {}   ## fish id (String) -> {"count": int, "biggest": float, "smallest": float}

## Notes a catch and says what was new about it: {"first": bool, "biggest": bool, "smallest": bool}.
## A first catch of a species is "first" only (it is trivially the biggest and smallest).
func record(id: StringName, size: float) -> Dictionary:
	var key := String(id)
	if not _records.has(key):
		_records[key] = {"count": 1, "biggest": size, "smallest": size}
		return {"first": true, "biggest": false, "smallest": false}
	var r: Dictionary = _records[key]
	r["count"] = int(r["count"]) + 1
	var result := {"first": false, "biggest": size > float(r["biggest"]), "smallest": size < float(r["smallest"])}
	r["biggest"] = maxf(float(r["biggest"]), size)
	r["smallest"] = minf(float(r["smallest"]), size)
	return result

func has_caught(id: StringName) -> bool:
	return _records.has(String(id))

func count_of(id: StringName) -> int:
	return int((_records.get(String(id), {}) as Dictionary).get("count", 0))

func biggest(id: StringName) -> float:
	return float((_records.get(String(id), {}) as Dictionary).get("biggest", 0.0))

func smallest(id: StringName) -> float:
	return float((_records.get(String(id), {}) as Dictionary).get("smallest", 0.0))

func species_caught() -> int:
	return _records.size()

func total_caught() -> int:
	var n := 0
	for r in _records.values():
		n += int(r["count"])
	return n

func to_dict() -> Dictionary:
	return _records.duplicate(true)

func from_dict(d: Dictionary) -> void:
	_records.clear()
	for key in d:
		var r: Variant = d[key]
		if r is Dictionary:
			_records[String(key)] = {"count": int(r.get("count", 1)), "biggest": float(r.get("biggest", 1.0)), "smallest": float(r.get("smallest", 1.0))}
