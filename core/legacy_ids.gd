class_name LegacyIds
extends RefCounted
## Old ids -> current ids, so saves made before an item/ability was renamed
## still load their gear, hotbar and bag. Add a line here whenever you change
## an id in a library (the display name is separate and can change freely).

const MAP := {
	&"cloth_tunic": &"tunic",
	&"buckler": &"wooden_shield",
	&"rusty_sword": &"wooden_sword",
	&"second_wind": &"heal",
	&"shield_tonic": &"shield_restore",
	&"old_key": &"key",
}

static func fix(id: StringName) -> StringName:
	return MAP.get(id, id)
