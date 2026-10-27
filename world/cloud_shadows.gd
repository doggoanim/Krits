class_name CloudShadows
extends Node3D
## Invisible blob-shaped planes drifting slowly overhead, casting nothing of
## themselves but a soft moving shadow patch on the terrain below — the
## sun (DirectionalLight3D) needs shadows enabled for this to show up at all
## (see EnvironmentConfig.sun_shadows, on by default). Each blob is a real
## mesh set to GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: Godot
## renders it into the shadow map but skips it entirely in the normal color
## pass, so nothing floats visibly in the sky — just its shadow, sliding
## across the ground beneath it.
##
## The blob shape itself is alpha-scissor cutout (not blended) specifically
## because Godot's shadow pass only respects a cutout alpha, not a blended
## one — a soft blended gradient would just cast a plain hard rectangle.
## Scissoring at shadow_alpha_threshold against the same soft round texture
## AmbientMotes' dust uses gives an irregular, roughly round cutout instead —
## the sun's own shadow_blur (EnvironmentConfig.sun_shadow_blur) then softens
## that cutout edge on the ground, which is what actually sells "cloud
## shadow" rather than "shape with a hard edge".
##
## Usage: add as a single node anywhere in a level — one instance manages
## several blobs drifting together across drift_area and wrapping back
## around once they pass out the far side. Unlike FoliageWind/AmbientMotes,
## this decorates the whole level from one node, not a specific prop.

@export var height := 25.0                     ## how high above this node's own Y the blobs drift
@export var drift_area := Vector2(80.0, 80.0)  ## how far blobs travel before wrapping back around
@export var blob_count := 4
@export var blob_size := Vector2(14.0, 10.0)
@export var drift_speed := 1.2                 ## world units/sec along +X — same travel direction WindGusts uses
@export var shadow_alpha_threshold := 0.3      ## higher = a smaller, patchier shadow cutout
## How far (world units, along the drift's own X travel) from each end of
## drift_area a blob spends fading — out just before it wraps back around,
## in just after. Without this, a blob's shadow patch pops fully into
## existence/vanishes the instant it crosses drift_area's edge, which reads
## as a glitch rather than a cloud drifting off. See _update_fade() for how
## the fade is actually achieved (there's no such thing as a partially-dark
## shadow here, so it's done by shrinking the alpha-scissor cutout itself).
@export var edge_fade_distance := 12.0

var _blobs: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	var tex := SoftCircleTexture.make(64)
	for i in blob_count:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = blob_size * randf_range(0.7, 1.3)
		mi.mesh = quad

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = shadow_alpha_threshold
		mat.albedo_texture = tex
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat

		mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # lay flat — same convention as VFX.landing_ring
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mi.position = Vector3(
			randf_range(-drift_area.x * 0.5, drift_area.x * 0.5),
			height,
			randf_range(-drift_area.y * 0.5, drift_area.y * 0.5),
		)
		add_child(mi)
		_blobs.append(mi)
		_mats.append(mat)

func _process(delta: float) -> void:
	for i in _blobs.size():
		var mi := _blobs[i]
		mi.position.x += drift_speed * delta
		if mi.position.x > drift_area.x * 0.5:
			mi.position.x -= drift_area.x
		_update_fade(mi, _mats[i])

## There's no such thing as a half-dark shadow pixel here — alpha-scissor
## shadow casting is binary per-pixel, fully in the shadow map or fully
## skipped (see the class doc comment on why scissor is used at all). So
## "fading" is done by shrinking the cutout instead of dimming it: the
## texture's own alpha is multiplied by albedo_color.a before the scissor
## test, so driving albedo_color.a toward 0 means fewer and fewer of the
## texture's pixels clear shadow_alpha_threshold, shrinking the patch down
## to nothing right as the blob reaches drift_area's edge — which, softened
## by the sun's own shadow_blur, reads as the cloud shadow fading away
## rather than a shape popping out of existence, then growing back in the
## same way once the blob wraps around and re-enters from the other side.
func _update_fade(mi: MeshInstance3D, mat: StandardMaterial3D) -> void:
	var half := drift_area.x * 0.5
	var dist_from_entry := mi.position.x - (-half)
	var dist_to_exit := half - mi.position.x
	var fade := clampf(minf(dist_from_entry, dist_to_exit) / edge_fade_distance, 0.0, 1.0)
	mat.albedo_color.a = fade
