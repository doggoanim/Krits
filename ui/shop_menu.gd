class_name ShopMenu
extends MenuBase
## Buy/equip armor (HP), shields (Shield) and weapons (Damage) with gold
## earned from fights (see Arena._end()/PlayerStats.add_gold()). No
## toggle_action — opened by a ShopKeeper in the world, not a hotkey (see
## MenuBase._unhandled_input()'s empty-toggle_action guard).
##
## Items come from EquipmentLibrary's static catalog (all_armors()/
## all_shields()/all_weapons()) — add a new one there and it shows up here
## for free, same as EnemyLibrary feeding DebugTools' fight shortcuts.

static var instance: ShopMenu

func _ready() -> void:
	super._ready()
	instance = self

func refresh() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var s := Game.stats
	title("Gold: %d" % s.gold)
	_section("Armor (HP)", EquipmentLibrary.all_armors(), s.equipped_armor)
	_section("Shields (Shield)", EquipmentLibrary.all_shields(), s.equipped_shield)
	_section("Weapons (Damage)", EquipmentLibrary.all_weapons(), s.equipped_weapon)

func _section(heading: String, items: Array, equipped: EquipmentData) -> void:
	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 18)
	content.add_child(h)
	for item in items:
		_row(item, equipped != null and equipped.id == item.id)

func _row(item: EquipmentData, is_equipped: bool) -> void:
	var s := Game.stats
	var is_owned := s.is_owned(item)
	var h := HBoxContainer.new()

	var bonus := _bonus_text(item)
	var l := Label.new()
	l.text = "%s%s  —  %s" % [item.display_name, bonus, ("owned" if is_owned else "%dg" % item.price)]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)

	var b := Button.new()
	if is_equipped:
		b.text = "Equipped"
		b.disabled = true
	else:
		b.text = "Equip" if is_owned else "Buy"
		b.disabled = not is_owned and item.price > s.gold
		b.pressed.connect(func():
			s.buy(item)
			refresh())
	h.add_child(b)
	content.add_child(h)

## A short "+N stat" suffix so the list reads at a glance, without needing a
## separate column per possible stat (each item only ever has the one that
## matches its own slot).
func _bonus_text(item: EquipmentData) -> String:
	if item is ArmorData: return "  (+%d HP)" % item.hp_bonus
	if item is ShieldData: return "  (+%d Shield)" % item.shield_bonus
	if item is WeaponData: return "  (+%d Dmg)" % item.damage_bonus
	return ""
