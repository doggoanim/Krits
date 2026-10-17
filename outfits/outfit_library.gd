class_name OutfitLibrary
extends RefCounted
## Central registry. Later: load every .tres from res://outfits/data/ instead.

static var _outfits: Dictionary = {}

static func _build() -> void:
	if not _outfits.is_empty():
		return
	_add(&"default", "Traveler", Color(0.9, 0.6, 0.2), 0.0)
	_add(&"azure", "Azure Cloak", Color(0.25, 0.5, 0.95), 0.1)
	_add(&"crimson", "Crimson Guard", Color(0.85, 0.15, 0.2), 0.3)
	_add(&"verdant", "Verdant Scout", Color(0.3, 0.8, 0.4), 0.0)
	_add(&"void", "Void Walker", Color(0.2, 0.1, 0.3), 0.8)

static func _add(id: StringName, nm: String, col: Color, metal: float) -> void:
	var o := OutfitData.new()
	o.id = id
	o.display_name = nm
	o.color = col
	o.metallic = metal
	_outfits[id] = o

static func get_outfit(id: StringName) -> OutfitData:
	_build()
	return _outfits.get(id, _outfits[&"default"])

static func all() -> Array:
	_build()
	return _outfits.values()
