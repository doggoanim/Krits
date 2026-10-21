class_name MainMenu
extends Control
## Title screen: the game boots into this (see project.godot's run/main_scene)
## instead of straight into main.tscn. New Game wipes any existing save and
## starts fresh; Continue resumes whatever's on disk (disabled when there's
## nothing to resume); Quit exits the app. Layout lives in main_menu.tscn —
## plain default-styled Godot controls for now; swap the scene's art/theme
## once there's real menu art to build from.

const GAME_SCENE := "res://main.tscn"

@onready var _continue_btn: Button = %ContinueButton

func _ready() -> void:
	_continue_btn.disabled = not Game.has_save()
	%NewGameButton.pressed.connect(_on_new_game)
	_continue_btn.pressed.connect(_on_continue)
	%QuitButton.pressed.connect(_on_quit)

func _on_new_game() -> void:
	Game.delete_save()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_continue() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_quit() -> void:
	get_tree().quit()
