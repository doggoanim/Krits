class_name FishCatalog
extends RefCounted
## What can be pulled out of the water, and how hard each is to land. Add a
## fish by adding an entry here and an item of the same id in ItemLibrary (plus
## its name/description in data/descriptions.cfg).
##   weight      relative chance of being the catch
##   speed       how fast the fish darts about in the reel-in minigame (bar widths per second)
##   zone        width of the catch zone you steer, as a fraction of the bar (smaller = harder)

const FISH: Array[Dictionary] = [
	{"id": &"minnow", "weight": 40.0, "speed": 0.35, "zone": 0.30},
	{"id": &"perch", "weight": 30.0, "speed": 0.5, "zone": 0.25},
	{"id": &"silver_trout", "weight": 16.0, "speed": 0.7, "zone": 0.21},
	{"id": &"golden_koi", "weight": 5.0, "speed": 0.95, "zone": 0.17},
	{"id": &"bluegill", "weight": 14.0, "speed": 0.4, "zone": 0.28},
	{"id": &"carp", "weight": 10.0, "speed": 0.45, "zone": 0.26},
	{"id": &"catfish", "weight": 6.0, "speed": 0.6, "zone": 0.23},
	{"id": &"pike", "weight": 4.0, "speed": 0.8, "zone": 0.2},
	{"id": &"rainbow_trout", "weight": 3.0, "speed": 0.75, "zone": 0.19},
	{"id": &"lantern_eel", "weight": 1.5, "speed": 0.9, "zone": 0.16},
	{"id": &"moon_puffer", "weight": 1.0, "speed": 0.95, "zone": 0.15},
	{"id": &"old_sturgeon", "weight": 0.5, "speed": 1.1, "zone": 0.12},
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
