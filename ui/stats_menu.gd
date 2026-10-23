class_name StatsMenu
extends MenuBase
## Read-only summary now that stats are equipment-driven (see PlayerStats) —
## shopping/equipping happens at a shop (ShopMenu), not here. This just shows
## what you're currently carrying and the numbers it adds up to.

func _init() -> void:
	toggle_action = &"menu_stats"

func refresh() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var s := Game.stats
	title("Gold: %d" % s.gold)
	_row("HP", "%d / %d" % [s.hp, s.max_hp()], s.equipped_armor)
	_row("Shield", "%d / %d" % [s.shield, s.max_shield()], s.equipped_shield)
	_row("Damage", "%d" % s.damage(), s.equipped_weapon)

func _row(label: String, value: String, item: EquipmentData) -> void:
	var l := Label.new()
	var gear := item.display_name if item else "—"
	l.text = "%s: %s   (%s)" % [label, value, gear]
	content.add_child(l)
