class_name Pole
extends Node3D
## A standalone decorative climbable pole prop: builds its own trunk
## (collision + mesh) from radius/height. The actual climb-trigger is a
## PoleGrab child (see pole_grab.gd) — the same reusable component used to
## make an existing object (a tree trunk, say) climbable without a trunk of
## its own; this script just forwards height/grab_radius into it.

@export var radius := 0.25
@export var height := 4.0
@export var grab_radius := 0.6

@onready var _collision_shape: CollisionShape3D = %CollisionShape
@onready var _mesh: MeshInstance3D = %MeshInstance
@onready var _grab_zone: PoleGrab = %GrabZone

func _ready() -> void:
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = height
	_collision_shape.shape = cyl_shape
	_collision_shape.position.y = height * 0.5

	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = radius
	cyl_mesh.bottom_radius = radius
	cyl_mesh.height = height
	_mesh.mesh = cyl_mesh
	_mesh.position.y = height * 0.5

	_grab_zone.configure(height, grab_radius)
