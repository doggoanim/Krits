@tool
class_name SpatialSfx
extends RefCounted
## Small helpers for placing a 3D one-shot sound in the world (critters, props): load a list of
## takes at runtime (missing files are skipped, so a not-yet-imported sound never breaks a
## scene) and play one at a position, never the same take twice in a row.

## The streams that exist among `paths`.
static func load_takes(paths: Array) -> Array[AudioStream]:
	var takes: Array[AudioStream] = []
	for path in paths:
		if ResourceLoader.exists(path):
			var s := load(path) as AudioStream
			if s != null:
				takes.append(s)
	return takes

## Index of a random take, different from `last` when there is a choice.
static func pick(count: int, last: int) -> int:
	if count <= 1:
		return 0
	var i := randi() % count
	if i == last:
		i = (i + 1 + randi() % (count - 1)) % count
	return i

## Plays `stream` at `world_pos`, parented to `parent` (which frees it when done).
static func play(parent: Node, stream: AudioStream, world_pos: Vector3, volume_db := 0.0,
		pitch := Vector2(0.95, 1.05), max_distance := 25.0, unit_size := 5.0, bus := &"SFX") -> void:
	if stream == null or parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(pitch.x, pitch.y)
	p.bus = bus
	p.unit_size = unit_size
	p.max_distance = max_distance
	parent.add_child(p)
	p.global_position = world_pos
	p.finished.connect(p.queue_free)
	p.play()
