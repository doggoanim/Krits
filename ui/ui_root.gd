class_name UiRoot
extends CanvasLayer
## Owns every UI element so Main only needs one line to add the UI.
## Each piece is now an editable .tscn (hud.tscn, stats_menu.tscn,
## travel_menu.tscn) instead of being built in code — instantiated here.

const HUD_SCENE := preload("res://ui/hud.tscn")
const STATS_MENU_SCENE := preload("res://ui/stats_menu.tscn")
const TRAVEL_MENU_SCENE := preload("res://ui/travel_menu.tscn")
const SHOP_MENU_SCENE := preload("res://ui/shop_menu.tscn")
const INTERACT_PROMPT_SCENE := preload("res://ui/interact_prompt.tscn")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")
const LOADING_SCREEN_SCENE := preload("res://ui/loading_screen.tscn")

var travel_menu: TravelMenu

func _ready() -> void:
	add_child(HUD_SCENE.instantiate())
	add_child(INTERACT_PROMPT_SCENE.instantiate())   # the "[E] Enter" prompt over doors/NPCs — see InteractPrompt
	add_child(STATS_MENU_SCENE.instantiate())
	travel_menu = TRAVEL_MENU_SCENE.instantiate() as TravelMenu
	add_child(travel_menu)
	add_child(SHOP_MENU_SCENE.instantiate())   # no toggle_action — opened by a ShopKeeper, see ShopMenu
	add_child(PAUSE_MENU_SCENE.instantiate())   # Esc — see PauseMenu
	add_child(DialogueBox.new())   # code-built, no scene file — see DialogueBox's own doc comment
	add_child(LOADING_SCREEN_SCENE.instantiate())   # Door's level-swap cover — see LoadingScreen
