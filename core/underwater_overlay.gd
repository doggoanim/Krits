class_name UnderwaterOverlay
extends Node
## Tints the screen toward the water's own color and muffles the mix whenever
## the CAMERA itself dips below a WaterVolume's surface — deliberately keyed
## off the camera, not the player (Player.water_submersion()/current_water()),
## since the spring-arm camera can end up underwater while the player stays
## dry (standing at the shore, camera pitched down into the lake) or vice
## versa (player swimming, camera pulled back above the surface) — see
## WaterVolume.at(), the static point lookup built for exactly this.
##
## Same bolt-on CanvasLayer + ColorRect pattern as LowHpVignette/
## PixelateEffect, minus the shader — a flat color tint needs no screen read,
## just the ColorRect's own alpha. The muffle reaches into AudioServer
## directly (a lowpass filter appended to the Master bus) since there's no
## existing effects bus to hook into otherwise.
##
## Usage: Main creates exactly one of these for the whole game, after the
## CameraRig exists — see main.gd.

const CANVAS_LAYER := -8   ## above PixelateEffect (-9), below the HUD (1) — same ordering reasoning as PixelateEffect's own header comment
const NORMAL_CUTOFF_HZ := 20000.0   ## effectively "off" — above the audible range, so the mix sounds unfiltered

@export var fade_speed := 4.0            ## how quickly the tint/muffle blend in or out as the camera crosses the surface
@export var tint_strength := 0.55        ## max overlay alpha once fully underwater (scales WaterVolume.tint_color's own alpha)
@export var muffled_cutoff_hz := 500.0   ## Master bus lowpass cutoff once fully underwater

var camera_rig: CameraRig

var _overlay: ColorRect
var _lowpass: AudioEffectLowPassFilter
var _bus_idx: int
var _blend := 0.0
var _last_tint := Color(0.08, 0.32, 0.42, 0.55)   ## held across the fade-out so leaving water doesn't
													## snap to a different default color while alpha is still easing down

func setup(rig: CameraRig) -> void:
	camera_rig = rig

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = CANVAS_LAYER
	add_child(canvas)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0, 0, 0, 0)
	canvas.add_child(_overlay)

	_bus_idx = AudioServer.get_bus_index("Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = NORMAL_CUTOFF_HZ
	AudioServer.add_bus_effect(_bus_idx, _lowpass)

func _process(delta: float) -> void:
	if camera_rig == null:
		return
	var cam := camera_rig.get_camera()
	if cam == null:
		return
	var water := WaterVolume.at(cam.global_position)
	var target := 1.0 if water != null else 0.0
	_blend = move_toward(_blend, target, fade_speed * delta)
	if water != null:
		_last_tint = water.tint_color

	_overlay.color = Color(_last_tint.r, _last_tint.g, _last_tint.b, _last_tint.a * tint_strength * _blend)
	_lowpass.cutoff_hz = lerpf(NORMAL_CUTOFF_HZ, muffled_cutoff_hz, _blend)
