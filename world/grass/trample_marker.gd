class_name TrampleMarker
extends MeshInstance3D
## Add as a child of anything that should press grass down — the player, a
## rolling prop, another character. Invisible in normal gameplay: it only
## renders on TrampleMap.TRAMPLE_LAYER, which nothing but TrampleMap's
## top-down capture camera looks at (see player_camera.gd's cull_mask,
## which explicitly excludes this layer from the real game view).

@export var radius := 0.6


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	mesh = plane

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	material_override = mat

	layers = TrampleMap.TRAMPLE_LAYER
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
