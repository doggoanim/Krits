class_name DialogueStage
extends RefCounted
## The in-world half of a conversation: freezes the player, points the
## camera at whoever is speaking and gets that speaker to turn toward the
## player — then puts everything back when the conversation ends.
##
## Everything here is optional. With no player (the main menu's name prompt)
## or no speaker node (a narration line) the matching part is simply skipped,
## so DialogueBox can drive any conversation without caring where it is.
##
## A speaker is any Node3D. If it implements these (NPC does) they're used:
##   get_focus_point() -> Vector3   where the camera should look (the head)
##   face_toward(world_pos)         turn to face the player
##   restore_facing()               go back to how it was standing

var player: Player

var _speaker: Node3D

func begin(speaker: Node3D, tree: SceneTree) -> void:
	player = tree.get_first_node_in_group(&"player") as Player
	_speaker = speaker
	if player == null:
		return
	player.enter_cinematic()
	if _speaker == null:
		return
	player.face(_speaker.global_position - player.global_position)
	if _speaker.has_method(&"face_toward"):
		_speaker.face_toward(player.global_position)
	if player.camera_rig:
		player.camera_rig.begin_focus(_speaker, _focus_point())

func end() -> void:
	if player == null:
		return
	if is_instance_valid(player):
		if player.camera_rig:
			player.camera_rig.end_focus()
		player.machine.transition_to(&"Ground")
	if is_instance_valid(_speaker) and _speaker.has_method(&"restore_facing"):
		_speaker.restore_facing()
	player = null
	_speaker = null

func _focus_point() -> Vector3:
	if _speaker.has_method(&"get_focus_point"):
		return _speaker.get_focus_point()
	return _speaker.global_position + Vector3.UP * 1.5
