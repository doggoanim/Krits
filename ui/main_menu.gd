class_name MainMenu
extends Control
## Title flow: the game boots into this (see project.godot's run/main_scene)
## instead of straight into main.tscn. It owns a persistent 3D backdrop
## (MenuStage: black void, stars, a white floating Krits) and a set of
## full-screen MenuScreen pages layered over it, showing one at a time:
##
##   Splash -> Title (press any key -> Play / Settings / Quit)
##          -> Save slots -> [empty slot] Name prompt -> dialogue -> game
##                        -> [used slot]  game
##
## Screens never move themselves — each emits MenuScreen.navigate and this
## script fades the old one out, runs any choreography (the one-time intro
## slide of Krits to the right), and fades the next one in. Adding a page is:
## new MenuScreen scene, instance it below, register it in _screens.

## Looping music for the whole menu, started as soon as it opens (see Music,
## core/music_player.gd). Main swaps it for the level's own track on load.
@export var title_music: AudioStream = preload("res://sounds/Music/title_track.ogg")

## Set by the pause menu's "Main Menu" button before it reloads this scene: skips
## the splash and lands straight on Play / Settings / Quit.
static var return_to_title := false

const GAME_SCENE := "res://main.tscn"
const SCREEN_FADE := 0.3
const FADE_TO_GAME := 0.8

@onready var _stage: MenuStage = %Stage
@onready var _fade: ColorRect = %FadeToBlack

## target name -> MenuScreen. &"game" and &"quit" are handled directly in
## _on_navigate() rather than being screens.
var _screens: Dictionary = {}
var _current: MenuScreen
var _busy := false          ## true while a transition runs, so a double-press can't stack two
var _intro_played := false  ## the splash -> title slide of Krits only ever happens once

func _ready() -> void:
	# The game's one shared dialogue box (see ui/dialogue_box.gd) — normally
	# built by UiRoot inside main.tscn, so the menu needs its own for the
	# name prompt's line. Same class, same look.
	add_child(DialogueBox.create())
	Music.play(title_music)

	_screens = {
		&"splash": %Splash,
		&"title": %Title,
		&"slots": %Slots,
		&"name": %NamePrompt,
		&"settings": %Settings,
	}
	for key in _screens:
		var screen: MenuScreen = _screens[key]
		screen.visible = false
		screen.modulate.a = 0.0
		screen.navigate.connect(_on_navigate)
	FocusPop.attach_all(self)   # the menu's focus look (see FocusPop) instead of Godot's default ring
	_fade.color.a = 0.0
	if return_to_title:
		return_to_title = false
		_intro_played = true
		await _stage.play_intro()
		await _show(&"title", {"show_menu": true})
		return
	# Splash appears instantly (no fade-in): it's an opaque black card, and
	# fading it in from transparent would flash the starfield behind it first.
	await _show(&"splash", {}, false)

func _on_navigate(target: StringName, payload: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	if _current:
		await _hide(_current)
	if target == &"quit":
		get_tree().quit()
		return
	if target == &"game":
		await _start_game(payload)
		return
	if target == &"title" and not _intro_played:
		_intro_played = true
		await _stage.play_intro()
	await _show(target, payload)
	_busy = false

func _show(target: StringName, payload: Dictionary, fade_in := true) -> void:
	var screen: MenuScreen = _screens[target]
	screen.modulate.a = 0.0 if fade_in else 1.0
	screen.visible = true
	_current = screen
	screen.enter(payload)
	if not fade_in:
		return
	var tw := create_tween()
	tw.tween_property(screen, "modulate:a", 1.0, SCREEN_FADE)
	await tw.finished

func _hide(screen: MenuScreen) -> void:
	var tw := create_tween()
	tw.tween_property(screen, "modulate:a", 0.0, SCREEN_FADE)
	await tw.finished
	screen.visible = false
	screen.exit()

## Points Game at the chosen slot (creating a brand-new save first when the
## name prompt asked for one), fades to black, and hands off to the game —
## Main's own Game.load_game() then reads whichever slot is current.
func _start_game(payload: Dictionary) -> void:
	var slot: int = payload.get("slot", Game.current_slot)
	if payload.get("new_game", false):
		Game.start_new_game(slot, String(payload.get("name", "Krits")))
	else:
		Game.select_slot(slot)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE_TO_GAME)
	await tw.finished
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		# The game scene (or one of its dependencies) failed to load —
		# surface it instead of leaving the player on a black screen.
		push_error("MainMenu: could not load %s (error %d)" % [GAME_SCENE, err])
		var back := create_tween()
		back.tween_property(_fade, "color:a", 0.0, FADE_TO_GAME)
		await back.finished
		_busy = false
