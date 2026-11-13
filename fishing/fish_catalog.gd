class_name FishCatalog
extends RefCounted
## What can be pulled out of the water, and how hard each is to land. Add a
## fish by adding an entry here and an item of the same id in ItemLibrary (plus
## its name/description in data/descriptions.cfg).
##   weight      relative chance of being the catch
##   speed       how fast the fish darts about in the reel-in minigame (bar widths per second)
##   zone        width of the catch zone you steer, as a fraction of the bar (smaller = harder)
##   length      metres long at the normal size (a caught fish is this x its random size, see roll_size())

const FISH: Array[Dictionary] = [
	{"id": &"minnow", "weight": 40.0, "speed": 0.35, "zone": 0.30, "length": 0.25},
	{"id": &"perch", "weight": 30.0, "speed": 0.5, "zone": 0.25, "length": 0.4},
	{"id": &"silver_trout", "weight": 16.0, "speed": 0.7, "zone": 0.21, "length": 0.5},
	{"id": &"golden_koi", "weight": 5.0, "speed": 0.95, "zone": 0.17, "length": 0.55},
	{"id": &"bluegill", "weight": 14.0, "speed": 0.4, "zone": 0.28, "length": 0.35},
	{"id": &"carp", "weight": 10.0, "speed": 0.45, "zone": 0.26, "length": 0.6},
	{"id": &"catfish", "weight": 6.0, "speed": 0.6, "zone": 0.23, "length": 0.65},
	{"id": &"pike", "weight": 4.0, "speed": 0.8, "zone": 0.2, "length": 0.8},
	{"id": &"rainbow_trout", "weight": 3.0, "speed": 0.75, "zone": 0.19, "length": 0.55},
	{"id": &"lantern_eel", "weight": 1.5, "speed": 0.9, "zone": 0.16, "length": 0.9},
	{"id": &"moon_puffer", "weight": 1.0, "speed": 0.95, "zone": 0.15, "length": 0.4},
	{"id": &"old_sturgeon", "weight": 0.5, "speed": 1.1, "zone": 0.12, "length": 1.0},
]

## A random catch, weighted.
static func roll() -> Dictionary:
	var total := 0.0
	for f in FISH:
		total += float(f["weight"])
	var pick := randf() * total
	for f in FISH:
		pick -= float(f["weight"])
		if pick <= 0.0:
			return f
	return FISH[0]

## How rare a fish is, as the N in "1 in N" (its share of the total catch
## weight, rounded to a whole number; at least 1).
static func odds(id: StringName) -> int:
	var total := 0.0
	var weight := 0.0
	for f in FISH:
		total += float(f["weight"])
		if f["id"] == id:
			weight = float(f["weight"])
	if weight <= 0.0:
		return 1
	return maxi(1, roundi(total / weight))

## "1 in 4" — shown under the fish's name when it is caught.
static func rarity_text(id: StringName) -> String:
	return "1 in %d" % odds(id)


# ------------------------------------------------------------------- size
## Every catch has a random size, a multiplier on the fish's normal length. Most
## are close to 1.0; a few are comically tiny or comically huge.

const SIZE_TINY := 0.4        ## below this: Tiny
const SIZE_SMALL := 0.7
const SIZE_NORMAL_MAX := 1.45
const SIZE_BIG_MAX := 2.5
const SIZE_HUGE_MAX := 4.0    ## above this: Colossal (up to SIZE_MAX)
const SIZE_MAX := 8.0

## The size multiplier of a fresh catch: ~80% are normal (about 0.7-1.45x),
## the rest spread over tiny / small / big / huge / colossal.
static func roll_size() -> float:
	var r := randf()
	if r < 0.04:
		return randf_range(0.1, SIZE_TINY)
	if r < 0.10:
		return randf_range(SIZE_TINY, SIZE_SMALL)
	if r < 0.90:
		return clampf(randfn(1.0, 0.18), SIZE_SMALL, SIZE_NORMAL_MAX)
	if r < 0.96:
		return randf_range(SIZE_NORMAL_MAX, SIZE_BIG_MAX)
	if r < 0.99:
		return randf_range(SIZE_BIG_MAX, SIZE_HUGE_MAX)
	return lerpf(SIZE_HUGE_MAX, SIZE_MAX, pow(randf(), 2.0))   # skewed low: a true maximum is very rare

## "Tiny", "Colossal"... or "" for an ordinary-sized fish.
static func size_word(size: float) -> String:
	if size < SIZE_TINY: return "Tiny"
	if size < SIZE_SMALL: return "Small"
	if size <= SIZE_NORMAL_MAX: return ""
	if size <= SIZE_BIG_MAX: return "Big"
	if size <= SIZE_HUGE_MAX: return "Huge"
	return "Colossal"

static func base_length(id: StringName) -> float:
	for f in FISH:
		if f["id"] == id:
			return float(f["length"])
	return 0.4

## Metres long this particular fish is.
static func length_of(id: StringName, size: float) -> float:
	return base_length(id) * size

## "12 cm", "480 cm" — always centimetres.
static func length_text(id: StringName, size: float) -> String:
	return "%d cm" % maxi(1, roundi(length_of(id, size) * 100.0))

static func is_fish(id: StringName) -> bool:
	for f in FISH:
		if f["id"] == id:
			return true
	return false
