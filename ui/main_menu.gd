class_name MainMenu
extends Control
## Title screen: the game boots into this (see project.godot's run/main_scene)
## instead of straight into main.tscn. New Game wipes any existing save and
## starts fresh; Continue resumes whatever's on disk (disabled when there's
## nothing to resume); Quit exits the app. Plain default-styled Godot
## controls for now — same starting point the HUD had before its own design
## pass; swap this out once there's real menu art to build from.

const GAME_SCENE := "res://main.tscn"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(260.0, 0.0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var title := Label.new()
	title.text = "Krits"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 24.0)
	box.add_child(spacer)

	var new_game := Button.new()
	new_game.text = "New Game"
	new_game.pressed.connect(_on_new_game)
	box.add_child(new_game)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.disabled = not Game.has_save()
	continue_btn.pressed.connect(_on_continue)
	box.add_child(continue_btn)

	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(_on_quit)
	box.add_child(quit)

func _on_new_game() -> void:
	Game.delete_save()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_continue() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_quit() -> void:
	get_tree().quit()
