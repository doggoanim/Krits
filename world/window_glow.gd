class_name WindowGlow
extends Node
## Lights the houses' windows at night. The Chesburg house models have their window panes on
## one emissive material ("Material.003"); this gives every house its own copy of it and
## drives it from the clock: dim glass by day, a warm glow from dusk, and each house goes
## dark at its own bedtime so the street winds down house by house instead of all at once.
## The glow wavers a little, like candlelight, held in stepped poses (see Choppy).
##
## Put one next to the HouseDressing node. It adopts every house whose name contains one of
## `name_filter` in its parent. In the editor the original material is left alone.

@export var name_filter: PackedStringArray = ["house_chesburg"]
@export var pane_material_name := "Material.003"
@export var day_energy := 0.12              ## glass by day: barely lit
@export var night_energy := 1.8
@export var warm_tint := Color(1.0, 0.86, 0.6)
@export_range(0.0, 0.3) var flicker := 0.06
## Bedtime window (hours, may pass midnight): each house picks its own time in it. Everything
## is back on at dusk the next evening.
@export var bedtime := Vector2(22.0, 26.0)
@export var fade_seconds := 2.5             ## real seconds a house takes to switch on or off

class House:
	var materials: Array[StandardMaterial3D] = []
	var bedtime := 23.0
	var seed := 0.0
	var level := 0.0

var _houses: Array[House] = []
var _last_step := -1

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	var holder := get_parent()
	if holder == null:
		set_process(false)
		return
	for child in holder.get_children():
		if child is Node3D and _matches(child.name):
			var h := House.new()
			_collect(child, h)
			if h.materials.is_empty():
				continue
			h.bedtime = randf_range(bedtime.x, bedtime.y)
			h.seed = randf() * 100.0
			_houses.append(h)
	set_process(not _houses.is_empty())

func _matches(node_name: StringName) -> bool:
	for f in name_filter:
		if String(node_name).contains(f):
			return true
	return false

## Gives `h` its own copy of every window material under `node`.
func _collect(node: Node, h: House) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i) as StandardMaterial3D
			if mat == null or mat.resource_name != pane_material_name:
				continue
			var own := mat.duplicate() as StandardMaterial3D   # per house: each one switches on its own
			own.emission_enabled = true
			mi.set_surface_override_material(i, own)
			h.materials.append(own)
	for child in node.get_children():
		_collect(child, h)

func _process(delta: float) -> void:
	var dusk := WorldClock.lamp_amount()
	var step := Choppy.index()
	var new_step := step != _last_step
	_last_step = step
	var t := Choppy.time()
	for h in _houses:
		var target := dusk if _awake(h) else 0.0
		var before := h.level
		h.level = move_toward(h.level, target, delta / maxf(fade_seconds, 0.01))
		if new_step or h.level != before:   # the flicker is held in poses; fades are smooth
			_apply(h, t)

## Awake from dusk until its bedtime. After midnight the hour counts on from 24, so a
## bedtime of 25.5 means half past one.
func _awake(h: House) -> bool:
	var hour := WorldClock.hour
	var evening := hour if hour >= 12.0 else hour + 24.0
	return evening < h.bedtime

func _apply(h: House, t: float) -> void:
	var wobble := (sin(t * 5.0 + h.seed) * 0.6 + sin(t * 11.3 + h.seed * 1.7) * 0.4) * flicker
	var energy := lerpf(day_energy, night_energy, h.level) * (1.0 + wobble * h.level)
	var tint := Color.WHITE.lerp(warm_tint, h.level)
	for m in h.materials:
		m.emission_energy_multiplier = energy
		m.emission = tint
