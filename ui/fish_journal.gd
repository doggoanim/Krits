class_name FishJournal
extends MenuBase
## The fish journal (hotkey "menu_fish_journal", default J): every fish in FishCatalog, with how
## many you've caught and your biggest and smallest. Fish you haven't caught show as ???, with a
## hint of which water they live in; catching one reveals its name and when it bites.
## Data comes from Game.fish_log; what a fish is and where it lives from FishCatalog.

const TITLE_SIZE := 80
const SUB_SIZE := 30
const ROW_SIZE := 26
const OUTLINE := 12
const KEY_PLATE := preload("res://ui/widgets/key_hint_plate.tscn")
const COLUMNS := ["Fish", "Caught", "Biggest", "Smallest", "Found in"]
const COLUMN_WIDTHS := [260.0, 110.0, 150.0, 150.0, 420.0]
const UNKNOWN := "???"
const COLOR_DONE := Color(1, 1, 1)
const COLOR_HIDDEN := Color(1, 1, 1, 0.45)

static var instance: FishJournal

var is_in_combat := func() -> bool: return false

func _ready() -> void:
	super._ready()
	instance = self
	toggle_action = &"menu_fish_journal"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func can_open() -> bool:
	if Game.in_combat or is_in_combat.call():
		return false
	return true

func refresh() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var total := FishCatalog.FISH.size()
	content.add_child(_heading("Fish Journal", TITLE_SIZE))
	content.add_child(_heading("%d of %d species  ·  %d caught" % [Game.fish_log.species_caught(), total, Game.fish_log.total_caught()], SUB_SIZE, 8))
	content.add_child(_table())
	_add_close_hint()

func _table() -> Control:
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	for i in COLUMNS.size():
		grid.add_child(_cell(COLUMNS[i], COLUMN_WIDTHS[i], Color(1.0, 0.9, 0.55), true))
	for f in FishCatalog.FISH:
		_add_row(grid, f)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	pad.add_child(grid)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.custom_minimum_size = Vector2(1300.0, minf(get_viewport_rect().size.y - 380.0, 560.0))
	scroll.add_child(pad)
	return scroll

func _add_row(grid: GridContainer, f: Dictionary) -> void:
	var id: StringName = f["id"]
	var caught := Game.fish_log.has_caught(id)
	var item := ItemLibrary.by_id(id)
	var name_text := (item.display_name if item != null else String(id)) if caught else UNKNOWN
	var color := COLOR_DONE if caught else COLOR_HIDDEN
	grid.add_child(_cell(name_text, COLUMN_WIDTHS[0], color))
	grid.add_child(_cell(str(Game.fish_log.count_of(id)) if caught else UNKNOWN, COLUMN_WIDTHS[1], color))
	grid.add_child(_cell(FishCatalog.length_text(id, Game.fish_log.biggest(id)) if caught else UNKNOWN, COLUMN_WIDTHS[2], color))
	grid.add_child(_cell(FishCatalog.length_text(id, Game.fish_log.smallest(id)) if caught else UNKNOWN, COLUMN_WIDTHS[3], color))
	grid.add_child(_cell(_where(f, caught), COLUMN_WIDTHS[4], color))

## "Lake, River · Night"; before the first catch only the water is hinted.
func _where(f: Dictionary, caught: bool) -> String:
	var areas: Array = f.get("areas", [])
	var times: Array = f.get("times", [])
	var water := "Anywhere" if areas.is_empty() else ", ".join(areas.map(func(a: Variant) -> String: return String(a).capitalize()))
	if not caught:
		return water
	if times.is_empty():
		return water
	return "%s  ·  %s" % [water, ", ".join(times.map(func(t: Variant) -> String: return String(t).capitalize()))]

func _cell(text: String, width: float, color: Color, header := false) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.add_theme_font_size_override("font_size", ROW_SIZE)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Ink.INK)
	l.add_theme_constant_override("outline_size", 8 if header else 6)
	return l

## White text with a thick black outline, the menus' sticker-style heading.
func _heading(text: String, size: int, outline := OUTLINE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Ink.INK)
	l.add_theme_constant_override("outline_size", outline)
	return l

func _add_close_hint() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var plate := KEY_PLATE.instantiate() as KeyHintPlate
	row.add_child(plate)
	plate.set_key("Esc")
	row.add_child(_heading("Close", 32, 8))
