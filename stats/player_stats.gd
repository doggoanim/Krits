class_name PlayerStats
extends RefCounted
## Level, XP, spendable points and the three stats: HP, Shield, Damage.
## Shield is a second bar that recharges after a delay. Piercing hits skip it.

const BASE_HP := 100.0
const BASE_SHIELD := 50.0
const BASE_DAMAGE := 10.0
const HP_PER_POINT := 20.0
const SHIELD_PER_POINT := 15.0
const DAMAGE_PER_POINT := 3.0
const POINTS_PER_LEVEL := 3
const SHIELD_RECHARGE_DELAY := 3.0
const SHIELD_RECHARGE_RATE := 12.0

var level := 1
var xp := 0
var points := 0
var invested := {&"hp": 0, &"shield": 0, &"damage": 0}

var hp := BASE_HP
var shield := BASE_SHIELD
var _since_hit := 0.0

func max_hp() -> float: return BASE_HP + invested[&"hp"] * HP_PER_POINT
func max_shield() -> float: return BASE_SHIELD + invested[&"shield"] * SHIELD_PER_POINT
func damage() -> float: return BASE_DAMAGE + invested[&"damage"] * DAMAGE_PER_POINT
func xp_to_next() -> int: return 50 + (level - 1) * 35

func tick(delta: float) -> void:
	_since_hit += delta
	if _since_hit >= SHIELD_RECHARGE_DELAY and shield < max_shield():
		shield = minf(max_shield(), shield + SHIELD_RECHARGE_RATE * delta)

## Returns true if the player died.
func take_damage(amount: float, pierces_shield := false) -> bool:
	_since_hit = 0.0
	if pierces_shield:
		hp -= amount
	else:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		hp -= amount - absorbed
	hp = maxf(hp, 0.0)
	Events.player_damaged.emit(hp, shield)
	return hp <= 0.0

func full_heal() -> void:
	hp = max_hp()
	shield = max_shield()
	Events.player_damaged.emit(hp, shield)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		points += POINTS_PER_LEVEL
		Events.leveled_up.emit(level)
	Events.stats_changed.emit()

func spend_point(stat: StringName) -> bool:
	if points <= 0 or not invested.has(stat):
		return false
	points -= 1
	invested[stat] += 1
	if stat == &"hp": hp += HP_PER_POINT
	if stat == &"shield": shield += SHIELD_PER_POINT
	Events.stats_changed.emit()
	return true

func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "points": points, "invested": {"hp": invested[&"hp"], "shield": invested[&"shield"], "damage": invested[&"damage"]}}

func from_dict(d: Dictionary) -> void:
	level = d.get("level", 1)
	xp = d.get("xp", 0)
	points = d.get("points", 0)
	var inv: Dictionary = d.get("invested", {})
	for k in invested.keys():
		invested[k] = int(inv.get(str(k), inv.get(k, 0)))
	full_heal()
