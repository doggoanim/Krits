class_name PropSfx
extends RefCounted
## One-shot positional sounds for the interactive props (smash, thunk, boing, ring...).

const BUS := &"SFX"
const WOOD_CHOP := preload("res://sounds/SFX/others/wood_chop.ogg")
const TINK := preload("res://sounds/SFX/others/hammer_tink.ogg")
const SQUEAK := preload("res://sounds/SFX/toy_squeak.wav")
const CLUCK := preload("res://sounds/SFX/others/chicken_clucking_1.ogg")

## Plays `stream` at `pos` (world space) under `parent`, pitched randomly within `pitch`.
static func play_at(parent: Node, stream: AudioStream, pos: Vector3, pitch := Vector2(0.9, 1.1), volume_db := 0.0) -> void:
	if parent == null or stream == null or not parent.is_inside_tree():
		return
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = stream
	sfx.bus = BUS
	sfx.volume_db = volume_db
	sfx.pitch_scale = randf_range(pitch.x, pitch.y)
	parent.get_tree().current_scene.add_child(sfx)
	sfx.global_position = pos
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
