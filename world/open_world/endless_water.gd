class_name EndlessWater
extends MeshInstance3D
## A huge water plane that follows the player on XZ, snapped to a grid so the
## shader's world-space waves never swim. Shares the lake's material, so the
## water keeps going until distance haze swallows it: from the shore there is
## no visible far bank, just lake fading into fog.

@export var surface_y := -0.84   ## just under the town's own sea-level water (Props/Water, y -0.82) so the two never z-fight
@export var extent := 1200.0
@export var snap := 8.0
@export var follow: Node3D

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent, extent)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = extent

func _process(_d: float) -> void:
	if follow == null:
		return
	var p := follow.global_position
	global_position = Vector3(snappedf(p.x, snap), surface_y, snappedf(p.z, snap))
