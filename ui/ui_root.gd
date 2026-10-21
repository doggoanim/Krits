class_name UiRoot
extends CanvasLayer
## Owns every UI element so Main only needs one line to add the UI.

var travel_menu: TravelMenu

func _ready() -> void:
	add_child(Hud.new())
	add_child(StatsMenu.new())
	travel_menu = TravelMenu.new()
	add_child(travel_menu)
