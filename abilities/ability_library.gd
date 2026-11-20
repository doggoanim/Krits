class_name AbilityLibrary
extends RefCounted
## Code-defined ability catalog (same spirit as ItemLibrary/EquipmentLibrary).
## Add a builder + list it in all_abilities(). Icons: drop a PNG at
## res://assets/abilities/<id>.png and it's picked up automatically.
## Names/descriptions live in data/descriptions.cfg ([names] / [abilities]).
## `starting()` are known (and hotbar-equipped) on a fresh save — currently none.

## false = every slot shows the first letter of its name in its colour instead of an
## icon PNG. Set to true to start using PNGs dropped in ICON_DIR again.
const USE_ICON_FILES := false
const ICON_DIR := "res://assets/abilities/"

static func heal() -> AbilityData:
	var a := _make(&"heal",
		AbilityData.Effect.HEAL, 15.0, 0, Color(1.0, 0.5, 0.55))
	a.amount = 30.0
	a.stamina_cost = 40.0
	return a

## A jump off thin air, as high as a normal jump (the runner uses the player's
## own jump velocity, so it follows any tuning of it) — usable mid-air.
static func air_step() -> AbilityData:
	var a := _make(&"air_step",
		AbilityData.Effect.AIR_STEP, 4.0, 0, Color(0.5, 0.85, 1.0))
	a.stamina_cost = 20.0
	return a

static func guard_up() -> AbilityData:
	var a := _make(&"guard_up",
		AbilityData.Effect.GUARD, 18.0, 0, Color(1.0, 0.9, 0.4))
	a.duration = 2.5
	a.stamina_cost = 35.0
	return a

static func shockwave() -> AbilityData:
	var a := _make(&"shockwave",
		AbilityData.Effect.SHOCKWAVE, 10.0, 0, Color(0.8, 0.55, 1.0))
	a.amount = 3.0   # x your damage stat
	a.radius = 9.0
	a.stamina_cost = 50.0
	return a

static func orb_stack() -> AbilityData:
	var a := _make(&"orb_stack",
		AbilityData.Effect.ORB_STACK, 14.0, 0, Color(1.0, 0.7, 0.3))
	a.amount = 10.0        # extra orbs stacked on the nearest orb...
	a.staff_amount = 2.0   # ...but only 2 with a staff
	a.stamina_cost = 80.0
	return a

## Cast a line at water in front of you (see FishingSession). Free to use, no cooldown.
static func fishing() -> AbilityData:
	return _make(&"fishing",
		AbilityData.Effect.FISH, 0.0, 0, Color(0.45, 0.8, 0.95))

static func all_abilities() -> Array[AbilityData]:
	return [heal(), air_step(), guard_up(), shockwave(), orb_stack(), fishing()]

## A new game starts with fishing; the rest are earned through quests and the story, not bought (a
## price of 0 keeps an ability out of every shop; give one a price to put it on sale again).
static func starting() -> Array[AbilityData]:
	return [fishing()]

static func by_id(id: StringName) -> AbilityData:
	id = LegacyIds.fix(id)   # saves from before a rename
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
	if USE_ICON_FILES and ResourceLoader.exists(path):
		a.icon = load(path)
	return a
