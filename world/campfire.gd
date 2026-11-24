@tool
class_name Campfire
extends Node3D
## A small camp fire: a ring of stones, crossed logs, a flickering painted flame (FireFx),
## rising embers and a warm light. By default it is only lit after dark (WorldClock);
## `always_lit` keeps it burning. Drop one in a level wherever someone camps.

@export var always_lit := false
@export var light_energy := 2.2
@export var light_range := 9.0

var _fire: Node3D
var _light: OmniLight3D
var _seed := 0.0
var _last_step := -1

func _ready() -> void:
	_seed = randf() * 50.0
	var stones := HouseParts.IRON.lightened(0.18)
	for i in 9:
		var a := TAU * float(i) / 9.0
		var stone := HouseParts.box(self, Vector3(0.2, 0.14, 0.16), stones.darkened(0.06 * (i % 3)), Vector3(cos(a) * 0.5, 0.07, sin(a) * 0.5))
		stone.rotation.y = -a
	for i in 3:
		var log := HouseParts.cylinder(self, 0.06, 0.8, HouseParts.WOOD_DARK, Vector3(0, 0.12, 0))
		log.rotation_degrees = Vector3(90, i * 60.0 + 15.0, 0)
	var ash := HouseParts.cylinder(self, 0.4, 0.02, Color(0.15, 0.13, 0.12), Vector3(0, 0.01, 0))
	ash.name = "Ash"
	_fire = Node3D.new()
	_fire.name = "Fire"
	add_child(_fire)
	var flames := FireFx.flame(0.75, 0.55, FireFx.PALETTE_FIRE, 3)
	flames.position.y = 0.12
	_fire.add_child(flames)
	var embers := FireFx.embers(10, 1.6, 1.2, 0.2, 0.07)
	embers.position.y = 0.3
	_fire.add_child(embers)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = light_range
	_light.omni_attenuation = 1.5
	_light.light_specular = 0.0
	_light.position = Vector3(0, 0.7, 0)
	add_child(_light)
	if Engine.is_editor_hint():
		set_process(false)
		return
	_update(true)

## True while the fire is burning (always, or once it's dark enough for lamps).
func is_lit() -> bool:
	return always_lit or WorldClock.lamp_amount() > 0.05

func _process(_delta: float) -> void:
	_update(false)

func _update(force: bool) -> void:
	var amount := 1.0 if always_lit else WorldClock.lamp_amount()
	var lit := amount > 0.05
	if _fire.visible != lit or force:
		_fire.visible = lit
		_light.visible = lit
	var step := Choppy.index()
	if lit and (step != _last_step or force):   # the flicker is held in poses (see Choppy)
		_last_step = step
		var t := Choppy.time() * 9.0 + _seed
		_light.light_energy = light_energy * amount * (1.0 + (sin(t) * 0.5 + sin(t * 2.3 + 1.0) * 0.3) * 0.15)
