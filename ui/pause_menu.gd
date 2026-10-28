class_name PauseMenu
extends MenuBase
## Esc in the world: freezes the game (MenuBase pauses the tree and frees the
## mouse) and shows Resume / Settings / Save Game / Main Menu / Quit. Built on
## MenuBase so it shares the "only one menu open at a time" rule with the stats
## / travel / shop menus, but its layout is a full-screen overlay defined in
## pause_menu.tscn, not MenuBase's small centred panel.
##
## Three layers, one visible at a time: the button page (`Content`), the
## Settings page (the same SettingsScreen the title menu uses), and a
## Yes/Cancel confirmation for the two actions that throw away unsaved
## progress. Esc always steps back one layer, and closes the menu from the top.

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"
const SAVED_MESSAGE_TIME := 1.5

@onready var _resume: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _save: Button = %SaveButton
@onready var _main_menu: Button = %MainMenuButton
@onready var _quit: Button = %QuitButton
@onready var _save_status: Label = %SaveStatus
@onready var _settings: SettingsScreen = %Settings
@onready var _confirm: Control = %Confirm
@onready var _confirm_message: Label = %ConfirmMessage
@onready var _confirm_yes: Button = %ConfirmYes
@onready var _confirm_no: Button = %ConfirmNo

var _on_confirmed := Callable()
var _status_tween: Tween

func _ready() -> void:
	super()
	_resume.pressed.connect(close)
	_settings_button.pressed.connect(_open_settings)
	_save.pressed.connect(_on_save)
	_main_menu.pressed.connect(_ask.bind("Return to the main menu?\nUnsaved progress is lost.", _go_main_menu))
	_quit.pressed.connect(_ask.bind("Quit the game?\nUnsaved progress is lost.", get_tree().quit))
	_confirm_yes.pressed.connect(_accept)
	_confirm_no.pressed.connect(_close_confirm)
	_settings.navigate.connect(func(_target: StringName, _payload: Dictionary) -> void: _close_settings())

func open() -> void:
	# Don't reopen on the very Esc press that just closed another menu.
	if Engine.get_process_frames() == last_close_frame:
		return
	super()
	if open_menu != self:
		return
	_settings.visible = false
	_confirm.visible = false
	content.visible = true
	_save_status.text = ""
	_resume.grab_focus()

# MenuBase's open() calls these; the pause menu's content is fixed in the scene.
func _clear() -> void:
	pass

func refresh() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel_menu"):
		return
	if not visible:
		open()
	elif _confirm.visible:
		_close_confirm()
	elif _settings.visible:
		return   # SettingsScreen handles its own Esc (-> navigate -> _close_settings)
	else:
		close()
	get_viewport().set_input_as_handled()

# --- Settings page ------------------------------------------------------------

func _open_settings() -> void:
	content.visible = false
	_settings.visible = true
	_settings.enter({})

func _close_settings() -> void:
	_settings.visible = false
	_settings.exit()
	content.visible = true
	_settings_button.grab_focus()

# --- Save ---------------------------------------------------------------------

func _on_save() -> void:
	Game.save()
	_save_status.text = "Saved to Slot %d" % Game.current_slot
	_save_status.modulate.a = 1.0
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(SAVED_MESSAGE_TIME)
	_status_tween.tween_property(_save_status, "modulate:a", 0.0, 0.5)

# --- Confirmation -------------------------------------------------------------

func _ask(message: String, action: Callable) -> void:
	_on_confirmed = action
	_confirm_message.text = message
	_confirm.visible = true
	_confirm_no.grab_focus()   # default to the safe choice

func _close_confirm() -> void:
	_confirm.visible = false
	_on_confirmed = Callable()
	_main_menu.grab_focus()

func _accept() -> void:
	var action := _on_confirmed
	_confirm.visible = false
	_on_confirmed = Callable()
	action.call()

func _go_main_menu() -> void:
	close()   # unpauses and clears open_menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MainMenu.return_to_title = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
