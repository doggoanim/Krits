class_name Pole
extends Node3D
## A vertical climbable pole (Mario 64-style). This script only builds the
## pole's shape from radius/height and wires its grab trigger — the actual
## climb behavior lives entirely in player/states/pole_climb_state.gd, the
## same split SlimePuddle uses (a trigger notifies Player, a state owns what
## happens next).
##
## radius/height drive everything here at runtime (the collision shapes and
## mesh in pole.tscn start out empty) rather than needing their numbers kept
## in sync with hand-authored sub-resources — resize a pole purely by
## changing these two exported fields in the Inspector.

@export var radius := 0.25
@export var height := 4.0
@export var grab_radius := 0.6   ## how far from the pole's centerline the grab trigger reaches —
								  ## bigger than `radius` so you don't have to touch the pole's
								  ## actual surface dead-on to catch it

@onready var _collision_shape: CollisionShape3D = %CollisionShape
@onready var _mesh: MeshInstance3D = %MeshInstance
@onready var _grab_shape: CollisionShape3D = %GrabShape
@onready var _grab_zone: Area3D = %GrabZone

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

	var grab_shape := CylinderShape3D.new()
	grab_shape.radius = grab_radius
	grab_shape.height = height
	_grab_shape.shape = grab_shape
	_grab_shape.position.y = height * 0.5

	_grab_zone.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.grab_pole(self)

## World-space Y the player can't climb above — just under the pole's own
## top, so the capsule doesn't poke out above it mid-climb.
func top_y() -> float:
	return global_position.y + height - 0.3
