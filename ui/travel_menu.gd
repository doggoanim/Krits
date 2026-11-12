class_name TravelMenu
extends MenuBase
## Fast travel screen: a full-screen overlay with one TravelCard per checkpoint
## in the current level (undiscovered ones show as locked silhouettes). Opens
## only while standing at a checkpoint — see can_open().

const TITLE_SIZE := 44
const CARD_GAP := 22
const SCREEN_MARGIN := 160.0      ## horizontal space kept free of the card row
const ROW_PADDING := 24.0         ## room around the cards so a focused (grown) card isn't clipped
const FADE_TIME := 0.2
const CARD_STAGGER := 0.05

var is_in_combat := func() -> bool: return false

func _init() -> void:
	toggle_action = &"menu_travel"

func _ready() -> void:
	super._ready()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 26)

func can_open() -> bool:
	if is_in_combat.call():
		Events.notice.emit("Can't fast travel during a fight.")
		return false
	if Spawnpoint.occupied(get_tree()) == null:
		Events.notice.emit("You can only fast travel from a checkpoint.")
		return false
	return true

func open() -> void:
	super.open()
	if open_menu == self:
		_play_intro()

func refresh() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	content.add_child(_heading("Fast Travel", TITLE_SIZE, Color.WHITE))
	content.add_child(_heading("Choose a checkpoint", 18, Color(1, 1, 1, 0.55)))
	var cards := _build_cards()
	content.add_child(_card_row(cards))
	content.add_child(_heading("[Esc] Close", 16, Color(1, 1, 1, 0.4)))
	FocusPop.attach_all(self, true)
	_focus_first_available.call_deferred(cards)

func _heading(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_cards() -> Array[TravelCard]:
	var here := Spawnpoint.occupied(get_tree())
	var cards: Array[TravelCard] = []
	var number := 1
	for n in get_tree().get_nodes_in_group(&"spawnpoints"):
		var sp := n as Spawnpoint
		var state := TravelCard.State.AVAILABLE
		if not sp.is_unlocked():
			state = TravelCard.State.LOCKED
		elif sp == here:
			state = TravelCard.State.HERE
		var card := TravelCard.new()
		card.setup(number, sp.display_name, sp.region_name, state)
		card.spawn_id = sp.spawn_id
		card.pressed.connect(_on_card_pressed.bind(card))
		cards.append(card)
		number += 1
	return cards

## The cards in a horizontally scrolling row, centered, and only as wide as
## it needs to be so a short list stays in the middle of the screen.
func _card_row(cards: Array[TravelCard]) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	for c in cards:
		row.add_child(c)
	var width := cards.size() * (TravelCard.CARD_SIZE.x + CARD_GAP) - CARD_GAP + ROW_PADDING * 2.0
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(ROW_PADDING))
	pad.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.custom_minimum_size = Vector2(
			minf(width, get_viewport_rect().size.x - SCREEN_MARGIN),
			TravelCard.CARD_SIZE.y + ROW_PADDING * 2.0)
	scroll.add_child(pad)
	return scroll

func _focus_first_available(cards: Array[TravelCard]) -> void:
	for c in cards:
		if c.state == TravelCard.State.AVAILABLE and is_instance_valid(c):
			c.grab_focus()
			return

func _on_card_pressed(card: TravelCard) -> void:
	close()
	Events.fast_travel_requested.emit(card.spawn_id)

## Whole screen fades up, the cards a beat after one another. Tweens run in
## pause mode PROCESS because the tree is paused while this menu is open.
func _play_intro() -> void:
	modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) \
			.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	var i := 0
	for c in find_children("*", "TravelCard", true, false):
		var card := c as TravelCard
		card.modulate.a = 0.0
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) \
				.tween_property(card, "modulate:a", 1.0, FADE_TIME) \
				.set_delay(CARD_STAGGER * i)
		i += 1
