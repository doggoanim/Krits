class_name DebugTools
extends Node
## Dev shortcuts for testing fights quickly. Only active in debug builds.
##  F1 green slime  F2 spinner  F3 piercer  F4 trio  F5 big group (6)
##  F6 cancel fight  F7 god mode  F9 full heal
##  F10 respawn defeated overworld enemies  F11 delete save  F12 add gold
## NOTE: deliberately skips F8 — that's the Godot editor's own global "Stop"
## shortcut, which intercepts the keypress before the running game ever sees
## it and kicks you straight back to the editor. +100 Gold lives on F12 instead.

const HELP := "F1 Green Slime  F2 Spinner  F3 Piercer  F4 Trio  F5 Big group\nF6 Cancel fight  F7 God mode  F9 Heal\nF10 Respawn defeated enemies  F11 Delete save  F12 +100 Gold"
const DEBUG_GOLD := 100

var player: Player
var encounters: EncounterManager
var _label: Label

func setup(p: Player, e: EncounterManager) -> void:
	player = p
	encounters = e

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20, 640)
	layer.add_child(_label)
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F1: _fight([EnemyLibrary.green_slime()])
		KEY_F2: _fight([EnemyLibrary.spinner()])
		KEY_F3: _fight([EnemyLibrary.piercer()])
		KEY_F4: _fight([EnemyLibrary.green_slime(), EnemyLibrary.spinner(), EnemyLibrary.piercer()])
		KEY_F5: _fight([EnemyLibrary.green_slime(), EnemyLibrary.green_slime(), EnemyLibrary.spinner(),
				EnemyLibrary.spinner(), EnemyLibrary.piercer(), EnemyLibrary.piercer()])
		KEY_F6: _cancel()
		KEY_F7:
			Game.god_mode = not Game.god_mode
			_update_label()
		KEY_F9: Game.stats.full_heal()
		KEY_F10:
			Game.reset_cleared_enemies()
			get_tree().reload_current_scene()
		KEY_F11:
			Game.delete_save()
			get_tree().reload_current_scene()
		KEY_F12: Game.stats.add_gold(DEBUG_GOLD)

func _cancel() -> void:
	if encounters.active_arena:
		encounters.active_arena.cancel()

func _fight(list: Array) -> void:
	if encounters.busy:
		return
	var roster: Array[EnemyData] = []
	roster.assign(list)
	encounters.begin_encounter(roster)   # no overworld enemies: straight to the dissolve

func _update_label() -> void:
	_label.text = HELP + ("\nGOD MODE ON" if Game.god_mode else "")
