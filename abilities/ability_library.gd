class_name AbilityLibrary
extends RefCounted
## Code-defined ability catalog (same spirit as ItemLibrary/EquipmentLibrary).
## Add a builder + list it in all_abilities(). Icons: drop a PNG at
## res://assets/abilities/<id>.png and it's picked up automatically.
## Names/descriptions live in data/descriptions.cfg ([names] / [abilities]).
## `starting()` are known (and hotbar-equipped) on a fresh save.

const ICON_DIR := "res://assets/abilities/"

static func heal() -> AbilityData:
	var a := _make(&"heal",
		AbilityData.Effect.HEAL, 15.0, 0, Color(1.0, 0.5, 0.55))
	a.amount = 30.0
	return a

static func super_jump() -> AbilityData:
	var a := _make(&"super_jump",
		AbilityData.Effect.SUPER_JUMP, 4.0, 0, Color(0.5, 0.85, 1.0))
	a.amount = 26.0
	return a

static func guard_up() -> AbilityData:
	var a := _make(&"guard_up",
		AbilityData.Effect.GUARD, 18.0, 80, Color(1.0, 0.9, 0.4))
	a.duration = 2.5
	return a

static func shockwave() -> AbilityData:
	var a := _make(&"shockwave",
		AbilityData.Effect.SHOCKWAVE, 10.0, 120, Color(0.8, 0.55, 1.0))
	a.amount = 3.0   # x your damage stat
	a.radius = 9.0
	return a

static func all_abilities() -> Array[AbilityData]:
	return [heal(), super_jump(), guard_up(), shockwave()]

static func starting() -> Array[AbilityData]:
	return [heal(), super_jump()]

static func by_id(id: StringName) -> AbilityData:
	for a in all_abilities():
		if a.id == id:
			return a
	return null

static func _make(id: StringName, effect: AbilityData.Effect,
		cooldown: float, price: int, color: Color) -> AbilityData:
	var a := AbilityData.new()
	a.id = id
	a.display_name = Descriptions.text("names", id)
	a.description = Descriptions.text("abilities", id)
	a.effect = effect
	a.cooldown = cooldown
	a.price = price
	a.color = color
	var path := ICON_DIR + String(id) + ".png"
	if ResourceLoader.exists(path):
		a.icon = load(path)
	return a
