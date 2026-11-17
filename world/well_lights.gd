class_name WellLights
extends Node
## Gives the well's lights a pulse. The cyan crystals breathe slowly, each a little behind
## its neighbour so a soft wave seems to drift through the cave, and each hums quietly when
## you come near. The warm torches flicker. All of it is held in stepped poses (see Choppy).
##
## Drop one in the level and point `lights_path` at the node holding the OmniLight3Ds; lights
## are picked up by name prefix, so adding another crystal or torch there is all it takes.

@export var lights_path: NodePath = ^"../AccentLights"
@export var crystal_prefix := "CyanCrystal"
@export var torch_prefix := "WarmTorch"

@export_group("Crystals")
@export var pulse_amount := 0.3          ## +/- fraction of the light's own energy
@export var pulse_period := 5.0          ## seconds for one breath
@export var wave_lag := 0.7              ## radians of delay between neighbouring crystals

@export_group("Torches")
@export var flicker_amount := 0.14
@export var flicker_speed := 9.0

@export_group("Hum")
@export var hum_stream: AudioStream      ## leave empty for the default crystal hum
@export var hum_volume_db := -20.0
@export var hum_range := 9.0
@export var bus := &"Ambience"

const HUM_DEFAULT := "res://sounds/Ambience/crystal_hum_loop.ogg"

class Glow:
	var light: OmniLight3D
	var base := 1.0
	var phase := 0.0

var _crystals: Array[Glow] = []
var _torches: Array[Glow] = []
var _last_step := -1

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	var holder := get_node_or_null(lights_path)
	if holder == null:
		set_process(false)
		return
	var stream := hum_stream if hum_stream != null else _load_hum()
	for child in holder.get_children():
		var light := child as OmniLight3D
		if light == null:
			continue
		var g := Glow.new()
		g.light = light
		g.base = light.light_energy
		if String(light.name).begins_with(crystal_prefix):
			g.phase = _crystals.size() * wave_lag
			_crystals.append(g)
			if stream != null:
				_add_hum(light, stream)
		elif String(light.name).begins_with(torch_prefix):
			g.phase = _torches.size() * 3.1
			_torches.append(g)

func _process(_delta: float) -> void:
	var step := Choppy.index()
	if step == _last_step:
		return   # hold the current pose
	_last_step = step
	var t := Choppy.time()
	for g in _crystals:
		g.light.light_energy = g.base * (1.0 + sin(t * TAU / pulse_period - g.phase) * pulse_amount)
	for g in _torches:
		var f := sin(t * flicker_speed + g.phase) * 0.6 + sin(t * flicker_speed * 2.3 + g.phase * 1.7) * 0.4
		g.light.light_energy = g.base * (1.0 + f * flicker_amount)

func _load_hum() -> AudioStream:
	return load(HUM_DEFAULT) as AudioStream if ResourceLoader.exists(HUM_DEFAULT) else null

func _add_hum(light: Node3D, stream: AudioStream) -> void:
	var s := stream.duplicate() as AudioStream   # a copy, so the loop flag doesn't leak onto the shared resource
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = bus
	p.volume_db = hum_volume_db
	p.unit_size = 2.0
	p.max_distance = hum_range
	p.autoplay = true
	light.add_child(p)
