class_name CharacterFillLight
extends OmniLight3D
## A soft, shadowless light that always sits between the camera and the
## player, a little above, so the side of the character you are LOOKING at is
## lit about the same no matter how you orbit the camera.
##
## Why: the toon shader bands lighting hard (lit / shadow), and in a dark level
## the only light on the character is the lantern at the left hip — so one side
## is lit and the other drops into the shadow tint, and orbiting the camera
## flips which one you see. This light supplies a gentle, consistent fill from
## the viewer's side. Keep it dim: it should even the character out, not
## replace the lantern.
##
## Added by Player next to the lantern; moves itself every frame.

@export var distance := 1.8        ## metres from the player toward the camera
@export var height := 0.9          ## metres above the player's origin
@export var fill_energy := 0.55
@export var fill_range := 3.2
@export var fill_color := Color(0.85, 0.92, 1.0)   ## slightly cool white

var _player: Player

func _ready() -> void:
	top_level = true   # world-space: placed by script each frame
	_player = get_parent() as Player
	light_color = fill_color
	light_energy = fill_energy
	omni_range = fill_range
	shadow_enabled = false
	light_specular = 0.0

func _process(_delta: float) -> void:
	if _player == null or _player.camera_rig == null:
		return
	var cam := _player.camera_rig.get_camera()
	if cam == null:
		return
	var from := _player.global_position + Vector3.UP * height
	var to_cam := cam.global_position - from
	to_cam.y = 0.0
	var dir := to_cam.normalized() if to_cam.length() > 0.01 else Vector3.BACK
	global_position = from + dir * distance + Vector3.UP * 0.3
