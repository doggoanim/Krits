@tool
class_name WaterHexShape
extends MeshInstance3D
## Attach as a per-instance script override on one specific water.tscn
## instance (set the Script property directly on that instance's node in the
## parent scene — same technique as overriding material_override or
## transform on an instance — never on water.tscn itself, or every water in
## the game would become a hexagon). Replaces that one instance's flat
## PlaneMesh with a procedurally-built hexagon (MeshUtil.hexagon_plane()) at
## the given size, leaving the shared water.tscn and every other instance of
## it untouched.
##
## @tool so the shape rebuilds live in the editor as you tweak radius/
## subdivisions in the Inspector, without needing to run the game to preview it.

@export var radius := 10.0:
	set(value):
		radius = value
		_rebuild()
@export var subdivisions := 6:
	set(value):
		subdivisions = maxi(1, value)
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	mesh = MeshUtil.hexagon_plane(radius, subdivisions)
