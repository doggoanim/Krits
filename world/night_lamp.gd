@tool
class_name NightLamp
extends Node
## Makes a light source follow the time of day: lanterns, campfire-side lights,
## and the OmniLights that go with them are dark in daylight and glow once
## WorldClock says it is dusk (and flicker a little, like a flame).
##
## Add it as a child of whatever holds the lamp, then register what it should
## drive — code that builds the lamp does this (HouseProps.lantern), or leave `auto_collect` on and it adopts every OmniLight3D/
## SpotLight3D underneath its parent by itself.
##
## In the editor it stays in its "day" state (no clock there), so the scene
## reads clearly while you build it.

@export var auto_collect := true
@export_range(0.0, 1.0) var flicker := 0.12     ## 0 = steady glow, 1 = wild candle
@export var flicker_speed := 7.0

class Lamp:
	var light: Light3D
	var energy := 1.0
	var material: StandardMaterial3D
	var emission_on := 1.0
	var emission_off := 0.0

var _lamps: Array[Lamp] = []
var _seed := 0.0
var _last_amount := -1.0

func _ready() -> void:
	_seed = randf() * 100.0
	if Engine.is_editor_hint():
		set_process(false)
		return
	if auto_collect and get_parent() != null:
		_collect(get_parent())
	_apply(0.0 if _lamps.is_empty() else WorldClock.lamp_amount(), 0.0)

func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Light3D and not _has_light(child):
			add_light(child, (child as Light3D).light_energy)
		_collect(child)

func _has_light(light: Light3D) -> bool:
	for l in _lamps:
		if l.light == light:
			return true
	return false

## Drive `light`: off by day, `energy` at night.
func add_light(light: Light3D, energy: float) -> void:
	var l := Lamp.new()
	l.light = light
	l.energy = energy
	_lamps.append(l)
	light.visible = false   # until it gets dark (the editor never lights it: no clock there)

## Drive an emissive `material`: `off` energy by day, `on` at night.
func add_material(material: StandardMaterial3D, on: float, off := 0.0) -> void:
	var l := Lamp.new()
	l.material = material
	l.emission_on = on
	l.emission_off = off
	_lamps.append(l)
	material.emission_enabled = true

func _process(_delta: float) -> void:
	var amount := WorldClock.lamp_amount()
	var wobble := 0.0
	if amount > 0.0 and flicker > 0.0:
		var t := Time.get_ticks_msec() / 1000.0 * flicker_speed + _seed
		wobble = (sin(t) * 0.5 + sin(t * 2.31 + 1.7) * 0.3 + sin(t * 5.1) * 0.2) * flicker
	elif amount == _last_amount:
		return   # fully on/off and not flickering: nothing to update
	_last_amount = amount
	_apply(amount, wobble)

func _apply(amount: float, wobble: float) -> void:
	for l in _lamps:
		if l.light != null:
			if not is_instance_valid(l.light):
				continue
			l.light.visible = amount > 0.01
			l.light.light_energy = l.energy * amount * (1.0 + wobble)
		elif l.material != null:
			l.material.emission_energy_multiplier = lerpf(l.emission_off, l.emission_on, amount) * (1.0 + wobble * 0.5)
