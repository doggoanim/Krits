@tool
class_name WorldZone
extends Node3D
## One streamed region of the open world. Place it in the world at the region's
## centre; ZoneStreamer instances `scene` as a child while the player is within
## `load_radius` and frees it again beyond `unload_radius` (keep unload larger
## so walking along the edge doesn't thrash).
##
## `mood` is the haze look inside the zone; it fades in over `mood_radius`.

@export var scene: PackedScene
@export var mood: ZoneMood
@export var load_radius := 120.0
@export var unload_radius := 160.0
@export var mood_radius := 90.0

var content: Node3D

func is_loaded() -> bool:
	return content != null and is_instance_valid(content)

func load_content() -> void:
	if is_loaded() or scene == null:
		return
	content = scene.instantiate() as Node3D
	add_child(content)

func unload_content() -> void:
	if is_loaded():
		content.queue_free()
	content = null

## 0..1 — how strongly this zone's mood applies at `pos`.
func mood_weight(pos: Vector3) -> float:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	return clampf(1.0 - d / maxf(mood_radius, 0.001), 0.0, 1.0)

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Set a scene."]) if scene == null else PackedStringArray()
