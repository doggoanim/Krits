class_name HotbarBar
extends HBoxContainer
## The six hotbar slots (1-3 abilities, 4-6 consumables), bottom-centre of
## the HUD. With `interactive` on (the HUD's instance) the number keys use the
## slots; the copy inside the inventory screen is display-only.

@export var slot_scene: PackedScene
@export var slot_styles: Array[StyleBox] = []   ## nine-sliced plates, one per slot (cycled)
@export var interactive := true
@export var slot_size := 96.0
@export var group_gap := 90.0   ## extra space between the ability slots (1-3) and consumable slots (4-6)

var _slots: Array[InventorySlot] = []

func _ready() -> void:
	for i in Hotbar.SLOT_COUNT:
		var slot := slot_scene.instantiate() as InventorySlot
		if i == Hotbar.ABILITY_SLOTS:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(group_gap, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(gap)
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		if not slot_styles.is_empty():
			var style := slot_styles[i % slot_styles.size()]
			for style_name in [&"normal", &"hover", &"pressed", &"disabled"]:
				slot.add_theme_stylebox_override(style_name, style)
		slot.set_key_text(str(i + 1))
		_slots.append(slot)

func _process(_delta: float) -> void:
	var hotbar := Game.hotbar
	for i in _slots.size():
		var slot := _slots[i]
		var id := hotbar.slots[i]
		slot.set_cooldown(0.0)
		slot.set_dim(false)
		if id == &"":
			slot.show_empty()
		elif Hotbar.is_ability_slot(i):
			var ability := AbilityLibrary.by_id(id)
			if ability:
				slot.show_ability(ability)
				slot.set_cooldown(hotbar.cooldown_fraction(id))
			else:
				slot.show_empty()
		else:
			var item := ItemLibrary.by_id(id)
			if item:
				var count := Game.inventory.count_of(id)
				slot.show_item(item, count)
				slot.set_dim(count == 0)
			else:
				slot.show_empty()

func _unhandled_input(event: InputEvent) -> void:
	if not interactive or not visible:
		return
	for i in Hotbar.SLOT_COUNT:
		if event.is_action_pressed(StringName("hotbar_%d" % (i + 1))):
			_try_use(i)
			get_viewport().set_input_as_handled()
			return

func _try_use(index: int) -> void:
	if get_tree().paused or Game.input_locked:
		return
	if DialogueBox.instance != null and DialogueBox.instance.is_active():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.dead or player.machine.current_name == &"Frozen":
		return
	if Game.hotbar.use_slot(index, player):
		_pop(_slots[index])

func _pop(slot: Control) -> void:
	slot.pivot_offset = slot.size * 0.5
	slot.scale = Vector2.ONE * 1.25
	create_tween().tween_property(slot, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
