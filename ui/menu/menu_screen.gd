class_name MenuScreen
extends Control
## Base for one full-screen page of the main menu (splash, title, save slots,
## name prompt, settings, ...). MainMenu owns every screen, shows exactly one
## at a time, and fades between them — a screen never shows or hides itself,
## it just asks to go somewhere else by emitting `navigate`.
##
## To add a page: make a scene whose root extends this, drop it into
## main_menu.tscn, and register it in MainMenu's `_screens` map. Nothing else
## about the flow needs to know it exists until something navigates to it.

## Asks MainMenu to move to another screen. `target` is a key in MainMenu's
## `_screens` map, or one of its two special targets: &"game" (hand off to
## main.tscn — `payload` carries "slot", and for a fresh save "new_game" +
## "name") and &"quit". `payload` is passed straight into the next screen's
## enter() so one page can hand data to the next (e.g. which slot was picked).
signal navigate(target: StringName, payload: Dictionary)

## Called by MainMenu right after this screen is made visible, every time it
## is shown — reset any transient state and grab focus here, not in _ready().
func enter(_payload: Dictionary = {}) -> void:
	pass

## Called by MainMenu once this screen has fully faded out.
func exit() -> void:
	pass
