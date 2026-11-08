class_name LevelAmbience
extends Node
## Drop into a level to give it a looping ambience bed (Ambience autoload, own
## volume slider in the audio settings). It starts when the level enters the
## scene and fades out when the level leaves.

@export var stream: AudioStream

func _ready() -> void:
	if not Engine.is_editor_hint():
		Ambience.play(stream, self)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		Ambience.stop(self)
