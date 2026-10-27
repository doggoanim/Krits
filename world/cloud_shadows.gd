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

var _blobs: Array[MeshInstance3D] = []

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

func _process(delta: float) -> void:
	for mi in _blobs:
		mi.position.x += drift_speed * delta
		if mi.position.x > drift_area.x * 0.5:
			mi.position.x -= drift_area.x
