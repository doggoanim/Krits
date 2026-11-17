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
@export_group("Spill light")
@export var spill_energy := 0.9             ## light thrown outside by each lit window; 0 turns it off
@export var spill_range := 4.5
@export var spill_color := Color(1.0, 0.8, 0.5)
@export var spill_out := 0.7                ## how far in front of the pane the light sits (m)
@export var active_distance := 45.0         ## windows further than this from the player throw no light
@export_group("")
@export var fade_seconds := 2.5             ## real seconds a house takes to switch on or off

class House:
	var materials: Array[StandardMaterial3D] = []
	var lights: Array[OmniLight3D] = []
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
			_collect(child, h, child as Node3D)
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
func _collect(node: Node, h: House, house: Node3D) -> void:
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
			if spill_energy > 0.0:
				h.lights.append(_make_spill(mi, house))
	for child in node.get_children():
		_collect(child, h, house)

## A small warm light just outside the pane: the pane's flat side is its normal, and the way
## that points away from the house's middle is outwards.
func _make_spill(pane: MeshInstance3D, house: Node3D) -> OmniLight3D:
	var box := pane.get_aabb()
	var axis := Vector3.RIGHT
	if box.size.y <= box.size.x and box.size.y <= box.size.z:
		axis = Vector3.UP
	elif box.size.z <= box.size.x and box.size.z <= box.size.y:
		axis = Vector3.BACK
	var normal := (pane.global_basis * axis).normalized()
	var centre := pane.global_transform * box.get_center()
	var away := centre - house.global_position
	away.y = 0.0
	if normal.dot(away) < 0.0:
		normal = -normal
	var light := OmniLight3D.new()
	light.light_color = spill_color
	light.light_energy = 0.0
	light.omni_range = spill_range
	light.shadow_enabled = false   # cheap: it only needs to warm the ground and wall
	light.visible = false
	add_child(light)
	light.global_position = centre + normal * spill_out
	return light

func _process(delta: float) -> void:
	var dusk := WorldClock.lamp_amount()
	var step := Choppy.index()
	var new_step := step != _last_step
	_last_step = step
	var t := Choppy.time()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	for h in _houses:
		var target := dusk if _awake(h) else 0.0
		var before := h.level
		h.level = move_toward(h.level, target, delta / maxf(fade_seconds, 0.01))
		if new_step or h.level != before:   # the flicker is held in poses; fades are smooth
			_apply(h, t, player)

## Awake from dusk until its bedtime. After midnight the hour counts on from 24, so a
## bedtime of 25.5 means half past one.
func _awake(h: House) -> bool:
	var hour := WorldClock.hour
	var evening := hour if hour >= 12.0 else hour + 24.0
	return evening < h.bedtime

func _apply(h: House, t: float, player: Node3D) -> void:
	var wobble := (sin(t * 5.0 + h.seed) * 0.6 + sin(t * 11.3 + h.seed * 1.7) * 0.4) * flicker
	var energy := lerpf(day_energy, night_energy, h.level) * (1.0 + wobble * h.level)
	var tint := Color.WHITE.lerp(warm_tint, h.level)
	for m in h.materials:
		m.emission_energy_multiplier = energy
		m.emission = tint
	for light in h.lights:
		var near := player == null or player.global_position.distance_to(light.global_position) < active_distance
		light.visible = h.level > 0.02 and near
		light.light_energy = spill_energy * h.level * (1.0 + wobble)
